# Import the module
$ModulePath = Split-Path -Parent $PSScriptRoot
Import-Module "$ModulePath\ECMA2HostTools.psd1" -Force

# Note: Mock -MockWith scriptblocks for -ModuleName ECMA2HostTools run inside the
# module's own scope, so they cannot see helper functions defined in this test script.
# The test sync job object is therefore built inline in each Mock block.

Describe 'Start-ECMA2ConnectorSyncJob' {
    Context 'Parameter Validation' {
        It 'Should have mandatory ServicePrincipalId and JobId parameters' {
            $command = Get-Command Start-ECMA2ConnectorSyncJob
            ($command.Parameters['ServicePrincipalId'].Attributes.Mandatory -contains $true) | Should Be $true
            ($command.Parameters['JobId'].Attributes.Mandatory -contains $true) | Should Be $true
        }

        It 'Should support ShouldProcess (WhatIf/Confirm)' {
            $command = Get-Command Start-ECMA2ConnectorSyncJob
            $command.Parameters.ContainsKey('WhatIf') | Should Be $true
            $command.Parameters.ContainsKey('Confirm') | Should Be $true
        }

        It 'Should restrict ApiVersion to v1.0 and beta' {
            $command = Get-Command Start-ECMA2ConnectorSyncJob
            $validation = $command.Parameters['ApiVersion'].Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateSetAttribute' }
            $validation.ValidValues | Should Be @('v1.0', 'beta')
        }
    }

    Context 'Job Not Found' {
        It 'Should error when the job cannot be found' {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith { $null }
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
            $errors = @()
            Start-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'missing' -ErrorVariable errors -ErrorAction SilentlyContinue -Confirm:$false
            $errors.Count -gt 0 | Should Be $true
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 0
        }
    }

    Context 'Already Running Guard' {
        It 'Should warn but still call Graph when the job is already running' {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Active'; IsRunning = $true; LastExecutionState = 'InProgress' }
            }
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
            $warnings = @()
            Start-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -WarningVariable warnings -WarningAction SilentlyContinue -Confirm:$false
            $warnings.Count -gt 0 | Should Be $true
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 1
        }

        It 'Should not warn when the job is paused (not running)' {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Paused'; IsRunning = $false; LastExecutionState = 'Succeeded' }
            }
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
            $warnings = @()
            Start-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -WarningVariable warnings -WarningAction SilentlyContinue -Confirm:$false
            $warnings.Count | Should Be 0
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 1
        }
    }

    Context 'ApiVersion / URI construction' {
        BeforeEach {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Paused'; IsRunning = $false; LastExecutionState = 'Succeeded' }
            }
        }

        It 'Should POST to the v1.0 start endpoint by default' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
            Start-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -Confirm:$false
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/v1.0/servicePrincipals/sp1/synchronization/jobs/job1/start' -and $Method -eq 'POST'
            }
        }

        It 'Should POST to the beta microsoft.graph.start endpoint when -ApiVersion beta is specified' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
            Start-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -ApiVersion beta -Confirm:$false
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/beta/servicePrincipals/sp1/synchronization/jobs/job1/microsoft.graph.start'
            }
        }
    }

    Context 'PassThru' {
        It 'Should include CurrentJob when -PassThru is specified' {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Active'; IsRunning = $false; LastExecutionState = 'Succeeded' }
            }
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
            $result = Start-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -PassThru -Confirm:$false
            $result.CurrentJob | Should Not BeNullOrEmpty
            Assert-MockCalled Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -Times 2
        }
    }

    Context 'WhatIf Support' {
        BeforeEach {
            Mock Get-ECMA2ConnectorSyncJob -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ Id = 'job1'; ServicePrincipalId = 'sp1'; StatusCode = 'Paused'; IsRunning = $false; LastExecutionState = 'Succeeded' }
            }
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { $null }
        }

        It 'Should not call Graph when -WhatIf is specified' {
            Start-ECMA2ConnectorSyncJob -ServicePrincipalId 'sp1' -JobId 'job1' -WhatIf
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -Times 0
        }
    }
}
