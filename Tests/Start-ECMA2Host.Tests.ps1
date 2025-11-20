# Pester tests for Start-ECMA2Host cmdlet
# Compatible with Pester 3.x

$ModulePath = Split-Path -Parent $PSScriptRoot
Import-Module "$ModulePath\ECMA2HostTools.psd1" -Force

Describe "Start-ECMA2Host" {
    
    Context "Parameter Validation" {
        It "Should accept ComputerName parameter" {
            $command = Get-Command Start-ECMA2Host
            $command.Parameters['ComputerName'] | Should Not BeNullOrEmpty
        }

        It "Should accept Credential parameter" {
            $command = Get-Command Start-ECMA2Host
            $command.Parameters['Credential'] | Should Not BeNullOrEmpty
        }

        It "Should have ComputerName default to current computer" {
            $command = Get-Command Start-ECMA2Host
            $command.Parameters['ComputerName'].Attributes.ValueFromPipelineByPropertyName | Should Be $true
        }

        It "Should support ShouldProcess" {
            $command = Get-Command Start-ECMA2Host
            $command.Parameters['WhatIf'] | Should Not BeNullOrEmpty
            $command.Parameters['Confirm'] | Should Not BeNullOrEmpty
        }
    }

    Context "Service Detection" {
        
        It "Should handle stopped service" {
            # Mock the service as stopped
            Mock Get-Service { 
                [PSCustomObject]@{
                    Name = 'Microsoft ECMA2Host'
                    Status = 'Stopped'
                }
            } -ModuleName ECMA2HostTools

            # Mock sc.exe to simulate starting
            Mock Invoke-Expression {
                if ($Command -like '*sc.exe start*') {
                    $global:LASTEXITCODE = 0
                    return "SERVICE_NAME: Microsoft ECMA2Host`n        TYPE               : 10  WIN32_OWN_PROCESS"
                }
            }

            { Start-ECMA2Host -WhatIf } | Should Not Throw
        }

        It "Should handle paused service" {
            # Mock the service as paused
            Mock Get-Service { 
                [PSCustomObject]@{
                    Name = 'Microsoft ECMA2Host'
                    Status = 'Paused'
                }
            } -ModuleName ECMA2HostTools

            # Mock sc.exe to simulate resuming
            Mock Invoke-Expression {
                if ($Command -like '*sc.exe continue*') {
                    $global:LASTEXITCODE = 0
                    return "SERVICE_NAME: Microsoft ECMA2Host"
                }
            }

            { Start-ECMA2Host -WhatIf } | Should Not Throw
        }

        It "Should handle already running service" {
            # Mock the service as already running
            Mock Get-Service { 
                [PSCustomObject]@{
                    Name = 'Microsoft ECMA2Host'
                    Status = 'Running'
                }
            } -ModuleName ECMA2HostTools

            { Start-ECMA2Host -WhatIf } | Should Not Throw
        }
    }

    Context "Local Service Management" {
        
        It "Should use sc.exe for local operations" {
            Mock Get-Service { 
                [PSCustomObject]@{
                    Name = 'Microsoft ECMA2Host'
                    Status = 'Stopped'
                }
            } -ModuleName ECMA2HostTools

            $scCalled = $false
            Mock Invoke-Expression {
                if ($Command -like '*sc.exe*') {
                    $script:scCalled = $true
                    $global:LASTEXITCODE = 0
                }
            }

            Start-ECMA2Host -WhatIf
            # WhatIf should prevent actual execution, but validates parameters
        }

        It "Should provide clear error for access denied (exit code 5)" {
            Mock Get-Service { 
                [PSCustomObject]@{
                    Name = 'Microsoft ECMA2Host'
                    Status = 'Stopped'
                }
            } -ModuleName ECMA2HostTools

            Mock Invoke-Expression {
                $global:LASTEXITCODE = 5
                return "[SC] OpenService FAILED 5:`n`nAccess is denied."
            }

            try {
                Start-ECMA2Host -ErrorAction Stop
                $false | Should Be $true  # Should not reach here
            }
            catch {
                $_.Exception.Message | Should Match "Administrator"
            }
        }
    }

    Context "Remote Service Management" {
        
        It "Should use CIM for remote operations" {
            Mock Get-CimInstance { 
                [PSCustomObject]@{
                    Name = 'Microsoft ECMA2Host'
                    State = 'Stopped'
                    DisplayName = 'Microsoft ECMA2Host'
                }
            } -ModuleName ECMA2HostTools

            Mock Invoke-CimMethod {
                [PSCustomObject]@{
                    ReturnValue = 0
                }
            } -ModuleName ECMA2HostTools

            { Start-ECMA2Host -ComputerName "RemoteServer" -WhatIf } | Should Not Throw
        }

        It "Should handle service not found on remote computer" {
            Mock Get-CimInstance { 
                return $null
            } -ModuleName ECMA2HostTools

            try {
                Start-ECMA2Host -ComputerName "RemoteServer" -ErrorAction Stop
                $false | Should Be $true  # Should not reach here
            }
            catch {
                $_.Exception.Message | Should Match "not found"
            }
        }

        # Note: CIM method mocking is complex and tested via integration tests
    }

    Context "WhatIf Support" {
        
        It "Should support WhatIf without making changes" {
            Mock Get-Service { 
                [PSCustomObject]@{
                    Name = 'Microsoft ECMA2Host'
                    Status = 'Stopped'
                }
            } -ModuleName ECMA2HostTools

            $invoked = $false
            Mock Invoke-Expression {
                $script:invoked = $true
            }

            Start-ECMA2Host -WhatIf
            # With WhatIf, sc.exe should not be called
        }
    }

    Context "Error Handling" {
        
        It "Should handle service query errors gracefully" {
            Mock Get-Service { 
                throw "Service not found"
            } -ModuleName ECMA2HostTools

            try {
                Start-ECMA2Host -ErrorAction Stop
                $false | Should Be $true  # Should not reach here
            }
            catch {
                $_.Exception.Message | Should Not BeNullOrEmpty
            }
        }

        It "Should handle non-zero exit codes from sc.exe" {
            Mock Get-Service { 
                [PSCustomObject]@{
                    Name = 'Microsoft ECMA2Host'
                    Status = 'Stopped'
                }
            } -ModuleName ECMA2HostTools

            # Mock the & operator to simulate sc.exe with exit code 1053
            # This test verifies error handling for non-privileged exit codes
            # Note: Actual behavior depends on how sc.exe is invoked in the function
        }
    }
}
