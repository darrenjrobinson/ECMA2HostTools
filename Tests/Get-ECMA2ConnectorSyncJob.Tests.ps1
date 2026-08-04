# Import the module
$ModulePath = Split-Path -Parent $PSScriptRoot
Import-Module "$ModulePath\ECMA2HostTools.psd1" -Force

Describe 'Get-ECMA2ConnectorSyncJob' {
    Context 'Parameter Validation' {
        It 'Should have mandatory ServicePrincipalId parameter' {
            $command = Get-Command Get-ECMA2ConnectorSyncJob
            ($command.Parameters['ServicePrincipalId'].Attributes.Mandatory -contains $true) | Should Be $true
        }

        It 'Should have optional JobId parameter' {
            $command = Get-Command Get-ECMA2ConnectorSyncJob
            ($command.Parameters['JobId'].Attributes.Mandatory -contains $true) | Should Be $false
        }

        It 'Should restrict ApiVersion to v1.0 and beta' {
            $command = Get-Command Get-ECMA2ConnectorSyncJob
            $validation = $command.Parameters['ApiVersion'].Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateSetAttribute' }
            $validation.ValidValues | Should Be @('v1.0', 'beta')
        }
    }

    Context 'Single Job Retrieval' {
        BeforeEach {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{
                    id         = 'job1'
                    templateId = 'template1'
                    schedule   = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }
                    status     = [PSCustomObject]@{
                        code          = 'Active'
                        lastExecution = [PSCustomObject]@{ state = 'Succeeded'; timeBegan = '2026-01-01T00:00:00Z' }
                        quarantine    = $null
                        escrows       = @()
                    }
                }
            }
        }

        It 'Should return job details for a specific JobId' {
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.Id | Should Be 'job1'
            $result.ScheduleState | Should Be 'Active'
            $result.LastExecutionState | Should Be 'Succeeded'
            $result.IsRunning | Should Be $false
        }

        It 'Should call the v1.0 endpoint by default' {
            Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1' | Out-Null
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/v1.0/servicePrincipals/11111111-1111-1111-1111-111111111111/synchronization/jobs/job1'
            }
        }

        It 'Should call the beta endpoint when -ApiVersion beta is specified' {
            Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1' -ApiVersion beta | Out-Null
            Assert-MockCalled Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/beta/servicePrincipals/11111111-1111-1111-1111-111111111111/synchronization/jobs/job1'
            }
        }

        It 'Should mark IsRunning true when lastExecution state is InProgress' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{
                    id         = 'job1'
                    templateId = 'template1'
                    schedule   = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }
                    status     = [PSCustomObject]@{
                        code          = 'Active'
                        lastExecution = [PSCustomObject]@{ state = 'InProgress'; timeBegan = '2026-01-01T00:00:00Z' }
                        quarantine    = $null
                        escrows       = @()
                    }
                }
            }
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.IsRunning | Should Be $true
        }
    }

    Context 'List Jobs' {
        It 'Should return multiple jobs when JobId is omitted' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{
                    value = @(
                        [PSCustomObject]@{ id = 'job1'; templateId = 't1'; schedule = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }; status = [PSCustomObject]@{ code = 'Active'; lastExecution = [PSCustomObject]@{ state = 'Succeeded'; timeBegan = $null }; quarantine = $null; escrows = @() } },
                        [PSCustomObject]@{ id = 'job2'; templateId = 't2'; schedule = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }; status = [PSCustomObject]@{ code = 'Active'; lastExecution = [PSCustomObject]@{ state = 'Succeeded'; timeBegan = $null }; quarantine = $null; escrows = @() } }
                    )
                }
            }
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111'
            $result.Count | Should Be 2
        }

        It 'Should warn when no jobs are found' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{ value = @() }
            }
            $warnings = @()
            Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count -gt 0 | Should Be $true
        }
    }

    Context 'Error Handling' {
        It 'Should write an error when the Graph request fails' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith { throw "Microsoft Graph request failed: Request_ResourceNotFound - Job not found" }
            $errors = @()
            Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'missing' -ErrorVariable errors -ErrorAction SilentlyContinue
            $errors.Count -gt 0 | Should Be $true
        }
    }
}
