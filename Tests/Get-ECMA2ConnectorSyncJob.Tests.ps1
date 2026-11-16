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
                        lastExecution = [PSCustomObject]@{ state = 'Succeeded'; timeBegan = '2026-01-01T00:00:00Z'; timeEnded = '2026-01-01T00:10:00Z' }
                        quarantine    = $null
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
                    }
                }
            }
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.IsRunning | Should Be $true
        }
    }

    Context 'Running Detection From Execution Times' {
        # $script: variables aren't visible inside module-scoped mocks, so each case
        # passes its values through environment variables.
        BeforeEach {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{
                    id         = 'job1'
                    templateId = 'template1'
                    schedule   = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }
                    status     = [PSCustomObject]@{
                        code          = $env:ECMA2_TEST_CODE
                        lastExecution = [PSCustomObject]@{
                            state     = 'Failed'
                            timeBegan = '2026-01-01T00:37:36Z'
                            timeEnded = $(if ($env:ECMA2_TEST_ENDED) { $env:ECMA2_TEST_ENDED } else { $null })
                        }
                        quarantine    = $null
                    }
                }
            }
            $env:ECMA2_TEST_CODE = 'Active'
            $env:ECMA2_TEST_ENDED = ''
        }

        AfterEach {
            Remove-Item Env:\ECMA2_TEST_CODE, Env:\ECMA2_TEST_ENDED -ErrorAction SilentlyContinue
        }

        It 'Should mark IsRunning true when the last execution has no end time' {
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.IsRunning | Should Be $true
            ($null -eq $result.LastExecutionEndTime) | Should Be $true
        }

        It 'Should mark IsRunning true when the end time is the 0001-01-01 placeholder' {
            $env:ECMA2_TEST_ENDED = '0001-01-01T00:00:00Z'
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.IsRunning | Should Be $true
            ($null -eq $result.LastExecutionEndTime) | Should Be $true
        }

        It 'Should mark IsRunning true when the end time is earlier than the start time' {
            $env:ECMA2_TEST_ENDED = '2026-01-01T00:22:51Z'
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.IsRunning | Should Be $true
        }

        It 'Should mark IsRunning false when the end time is after the start time' {
            $env:ECMA2_TEST_ENDED = '2026-01-01T00:45:00Z'
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.IsRunning | Should Be $false
        }

        It 'Should mark IsRunning false for a paused job even with no end time' {
            $env:ECMA2_TEST_CODE = 'Paused'
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.IsRunning | Should Be $false
        }
    }

    Context 'Timestamps and Escrows' {
        BeforeEach {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{
                    id         = 'job1'
                    templateId = 'template1'
                    schedule   = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }
                    status     = [PSCustomObject]@{
                        code                        = 'Active'
                        escrowsPruned               = $false
                        steadyStateLastAchievedTime = '2026-01-01T02:00:00Z'
                        lastExecution               = [PSCustomObject]@{
                            state            = 'EntryLevelErrors'
                            timeBegan        = '2026-01-01T00:00:00Z'
                            timeEnded        = '2026-01-01T00:10:00Z'
                            countEscrowed    = 1447
                            countEscrowedRaw = 1450
                        }
                        lastSuccessfulExecution     = [PSCustomObject]@{ timeEnded = '2025-12-31T23:00:00Z' }
                        quarantine                  = $null
                    }
                }
            }
        }

        It 'Should convert an ISO 8601 UTC string to a local DateTime' {
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $expected = (New-Object datetime 2026, 1, 1, 0, 0, 0, ([System.DateTimeKind]::Utc)).ToLocalTime()
            ($result.LastExecutionTime -is [datetime]) | Should Be $true
            $result.LastExecutionTime.Kind | Should Be ([System.DateTimeKind]::Local)
            $result.LastExecutionTime | Should Be $expected
        }

        It 'Should convert the other timestamps to local time' {
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.LastExecutionEndTime | Should Be (New-Object datetime 2026, 1, 1, 0, 10, 0, ([System.DateTimeKind]::Utc)).ToLocalTime()
            $result.LastSuccessfulExecutionTime | Should Be (New-Object datetime 2025, 12, 31, 23, 0, 0, ([System.DateTimeKind]::Utc)).ToLocalTime()
            $result.SteadyStateLastAchievedTime | Should Be (New-Object datetime 2026, 1, 1, 2, 0, 0, ([System.DateTimeKind]::Utc)).ToLocalTime()
        }

        It 'Should convert a UTC DateTime (as deserialized by PowerShell 7) to local time' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{
                    id         = 'job1'
                    templateId = 'template1'
                    schedule   = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }
                    status     = [PSCustomObject]@{
                        code          = 'Active'
                        lastExecution = [PSCustomObject]@{
                            state     = 'Succeeded'
                            timeBegan = (New-Object datetime 2026, 1, 1, 0, 0, 0, ([System.DateTimeKind]::Utc))
                        }
                        quarantine    = $null
                    }
                }
            }
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.LastExecutionTime.Kind | Should Be ([System.DateTimeKind]::Local)
            $result.LastExecutionTime | Should Be (New-Object datetime 2026, 1, 1, 0, 0, 0, ([System.DateTimeKind]::Utc)).ToLocalTime()
        }

        It 'Should return null timestamps when Graph supplies none' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{
                    id         = 'job1'
                    templateId = 'template1'
                    schedule   = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }
                    status     = [PSCustomObject]@{
                        code          = 'NotRun'
                        lastExecution = [PSCustomObject]@{ state = $null; timeBegan = $null }
                        quarantine    = $null
                    }
                }
            }
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            ($null -eq $result.LastExecutionTime) | Should Be $true
            ($null -eq $result.LastSuccessfulExecutionTime) | Should Be $true
        }

        It 'Should return the escrow counts from the last execution' {
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.EscrowCount | Should Be 1447
            $result.EscrowCountRaw | Should Be 1450
            $result.EscrowsPruned | Should Be $false
        }

        It 'Should convert quarantine timestamps to local time and keep the other details' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{
                    id         = 'job1'
                    templateId = 'template1'
                    schedule   = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }
                    status     = [PSCustomObject]@{
                        code          = 'Quarantine'
                        lastExecution = [PSCustomObject]@{ state = 'Failed'; timeBegan = '2026-01-01T00:00:00Z'; timeEnded = '2026-01-01T00:10:00Z' }
                        quarantine    = [PSCustomObject]@{
                            currentBegan = '2026-01-01T01:00:00Z'
                            nextAttempt  = (New-Object datetime 2026, 1, 1, 3, 0, 0, ([System.DateTimeKind]::Utc))
                            reason       = 'EncounteredEscrowProportionThreshold'
                            seriesBegan  = '2026-01-01T00:30:00Z'
                            seriesCount  = 2
                            error        = $null
                        }
                    }
                }
            }
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            $result.Quarantine.currentBegan | Should Be (New-Object datetime 2026, 1, 1, 1, 0, 0, ([System.DateTimeKind]::Utc)).ToLocalTime()
            $result.Quarantine.nextAttempt | Should Be (New-Object datetime 2026, 1, 1, 3, 0, 0, ([System.DateTimeKind]::Utc)).ToLocalTime()
            $result.Quarantine.seriesBegan | Should Be (New-Object datetime 2026, 1, 1, 0, 30, 0, ([System.DateTimeKind]::Utc)).ToLocalTime()
            $result.Quarantine.nextAttempt.Kind | Should Be ([System.DateTimeKind]::Local)
            $result.Quarantine.reason | Should Be 'EncounteredEscrowProportionThreshold'
            $result.Quarantine.seriesCount | Should Be 2
        }

        It 'Should return a null Quarantine when the job is not quarantined' {
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            ($null -eq $result.Quarantine) | Should Be $true
        }

        It 'Should not return the old Escrows property' {
            $result = Get-ECMA2ConnectorSyncJob -ServicePrincipalId '11111111-1111-1111-1111-111111111111' -JobId 'job1'
            ($result.PSObject.Properties.Name -contains 'Escrows') | Should Be $false
        }
    }

    Context 'List Jobs' {
        It 'Should return multiple jobs when JobId is omitted' {
            Mock Invoke-ECMA2GraphRequest -ModuleName ECMA2HostTools -MockWith {
                [PSCustomObject]@{
                    value = @(
                        [PSCustomObject]@{ id = 'job1'; templateId = 't1'; schedule = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }; status = [PSCustomObject]@{ code = 'Active'; lastExecution = [PSCustomObject]@{ state = 'Succeeded'; timeBegan = $null }; quarantine = $null } },
                        [PSCustomObject]@{ id = 'job2'; templateId = 't2'; schedule = [PSCustomObject]@{ state = 'Active'; interval = 'PT40M' }; status = [PSCustomObject]@{ code = 'Active'; lastExecution = [PSCustomObject]@{ state = 'Succeeded'; timeBegan = $null }; quarantine = $null } }
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
