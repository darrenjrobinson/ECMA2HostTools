# Import the module
$ModulePath = Split-Path -Parent $PSScriptRoot
Import-Module "$ModulePath\ECMA2HostTools.psd1" -Force

# Note: Mock -MockWith scriptblocks for -ModuleName ECMA2HostTools run inside the
# module's own scope, so they cannot see helper functions defined in this test script.
# The test sync job object is therefore built inline in each Mock block.

Describe 'Restart-ECMA2ConnectorSyncJob' {
    Context 'Parameter Validation' {
        It 'Should have mandatory ServicePrincipalId and JobId parameters' {
            $command = Get-Command Restart-ECMA2ConnectorSyncJob
            ($command.Parameters['ServicePrincipalId'].Attributes.Mandatory -contains $true) | Should Be $true
            ($command.Parameters['JobId'].Attributes.Mandatory -contains $true) | Should Be $true
        }

        It 'Should support ShouldProcess (WhatIf/Confirm)' {
            $command = Get-Command Restart-ECMA2ConnectorSyncJob
            $command.Parameters.ContainsKey('WhatIf') | Should Be $true
            $command.Parameters.ContainsKey('Confirm') | Should Be $true
        }

        It 'Should restrict ResetScope to the documented values' {
            $command = Get-Command Restart-ECMA2ConnectorSyncJob
            $validation = $command.Parameters['ResetScope'].Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateSetAttribute' }
            $validation.ValidValues | Should Be @('Escrows', 'Watermark', 'QuarantineState', 'ForceDeletes', 'Full', 'None', 'ConnectorDataStore')
        }
    }

    Context 'Dangerous Scope Guard' {
        BeforeEach {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Active'; IsRunning = $false; LastExecutionState = 'Succeeded' }
            }
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
        }

        It 'Should block ConnectorDataStore without -Force' {
            $errors = @()
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -ResetScope ConnectorDataStore -ErrorVariable errors -ErrorAction SilentlyContinue -Confirm:$false
            $errors.Count -gt 0 | Should Be $true
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 0
        }

        It 'Should block None without -Force' {
            $errors = @()
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -ResetScope None -ErrorVariable errors -ErrorAction SilentlyContinue -Confirm:$false
            $errors.Count -gt 0 | Should Be $true
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 0
        }

        It 'Should allow ConnectorDataStore with -Force' {
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -ResetScope ConnectorDataStore -Force -Confirm:$false
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 1
        }
    }

    Context 'Running Job Guard' {
        BeforeEach {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
        }

        It 'Should block a narrow reset (Escrows) while the job is running' {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Active'; IsRunning = $true; LastExecutionState = 'InProgress' }
            }
            $errors = @()
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -ErrorVariable errors -ErrorAction SilentlyContinue -Confirm:$false
            $errors.Count -gt 0 | Should Be $true
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 0
        }

        It 'Should allow a Full reset while the job is running' {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Active'; IsRunning = $true; LastExecutionState = 'InProgress' }
            }
            $warnings = @()
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -ResetScope Full -WarningVariable warnings -WarningAction SilentlyContinue -Confirm:$false
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 1
            $warnings.Count -gt 0 | Should Be $true
        }

        It 'Should allow a narrow reset while running when -Force is specified' {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Active'; IsRunning = $true; LastExecutionState = 'InProgress' }
            }
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -Force -Confirm:$false
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 1
        }

        It 'Should proceed normally when the job is not running' {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Active'; IsRunning = $false; LastExecutionState = 'Succeeded' }
            }
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -Confirm:$false
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 1
        }
    }

    Context 'Job Not Found' {
        It 'Should error when the job cannot be found' {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith { $null }
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
            $errors = @()
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'missing' -ErrorVariable errors -ErrorAction SilentlyContinue -Confirm:$false
            $errors.Count -gt 0 | Should Be $true
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 0
        }
    }

    Context 'ApiVersion / URI construction' {
        BeforeEach {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Active'; IsRunning = $false; LastExecutionState = 'Succeeded' }
            }
        }

        It 'Should POST to the v1.0 restart endpoint by default' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -Confirm:$false
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/v1.0/servicePrincipals/sp1/synchronization/jobs/job1/restart' -and $Method -eq 'POST'
            }
        }

        It 'Should POST to the beta microsoft.graph.restart endpoint when -ApiVersion beta is specified' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -ApiVersion beta -Confirm:$false
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/beta/servicePrincipals/sp1/synchronization/jobs/job1/microsoft.graph.restart'
            }
        }
    }

    Context 'WhatIf Support' {
        BeforeEach {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Active'; IsRunning = $false; LastExecutionState = 'Succeeded' }
            }
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
        }

        It 'Should not call Graph when -WhatIf is specified' {
            Restart-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -WhatIf
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 0
        }
    }
}
