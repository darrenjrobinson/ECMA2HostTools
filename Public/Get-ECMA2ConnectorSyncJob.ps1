function Get-ECMA2ConnectorSyncJob {
    <#
    .SYNOPSIS
        Gets Microsoft Entra cloud provisioning synchronization job details for a service principal.

    .DESCRIPTION
        Retrieves one or all synchronization jobs for the given service principal
        (enterprise application), including schedule and status - including whether
        the job's last run is still in progress, any active quarantine, and the
        number of escrowed entries (object-level errors being retried).
        Use this to confirm the correct servicePrincipalId/jobId, and current state,
        before calling Restart-ECMA2ConnectorSyncJob.

        IsRunning is true when the last execution has started but has no end time
        after its start time (and the job isn't paused). LastExecutionState is the
        result Graph reports for that execution and can read Failed or Succeeded
        while a run is still in progress.

        Timestamps are returned as DateTime values in the system's local time zone,
        including currentBegan, nextAttempt and seriesBegan inside Quarantine.
        EscrowCount and EscrowCountRaw come from the job's last execution;
        EscrowCountRaw also includes system-generated escrows.

        Requires a prior Connect-ECMA2Graph with Synchronization.Read.All or
        Synchronization.ReadWrite.All.

    .PARAMETER ServicePrincipalId
        The object ID of the service principal (enterprise application) the job belongs to.

    .PARAMETER JobId
        The synchronization job identifier. Omit to list all jobs for the service principal.

    .PARAMETER ApiVersion
        The Microsoft Graph API version to call. Defaults to v1.0.

    .EXAMPLE
        Get-ECMA2ConnectorSyncJob -ServicePrincipalId $spId -JobId $jobId

    .EXAMPLE
        Get-ECMA2ConnectorSyncJob -ServicePrincipalId $spId
        Lists all synchronization jobs for the service principal.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ServicePrincipalId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$JobId,

        [Parameter()]
        [ValidateSet('v1.0', 'beta')]
        [string]$ApiVersion = 'v1.0'
    )

    process {
        try {
            $baseUri = "https://graph.microsoft.com/$ApiVersion/servicePrincipals/$ServicePrincipalId/synchronization/jobs"
            $uri = if ($JobId) { "$baseUri/$JobId" } else { $baseUri }

            Write-Verbose "Getting synchronization job(s) from $uri"
            $response = Invoke-ECMA2GraphRequest -Method GET -Uri $uri

            $jobs = if ($JobId) { @($response) } else { $response.value }

            if (-not $jobs) {
                Write-Warning "No synchronization job(s) found for service principal '$ServicePrincipalId'"
                return
            }

            foreach ($job in $jobs) {
                $status = $job.status
                $lastExecution = $status.lastExecution
                $timeBegan = ConvertTo-ECMA2LocalDateTime -Value $lastExecution.timeBegan
                $timeEnded = ConvertTo-ECMA2LocalDateTime -Value $lastExecution.timeEnded

                # Graph's lastExecution.state only ever reports a result (Succeeded, Failed,
                # EntryLevelErrors), so it can't be used on its own to tell a run is in
                # progress. A run is in progress when it has a start time but no end time
                # after it - the same comparison the Entra portal shows as "In progress".
                # Compare the UTC instants, not the local values: during the daylight-saving
                # fall-back hour a later instant can have an earlier local clock time.
                $timeBeganUtc = ConvertTo-ECMA2LocalDateTime -Value $lastExecution.timeBegan -AsUtc
                $timeEndedUtc = ConvertTo-ECMA2LocalDateTime -Value $lastExecution.timeEnded -AsUtc
                $hasOpenExecution = $timeBeganUtc -and (-not $timeEndedUtc -or $timeEndedUtc -lt $timeBeganUtc)
                $isRunning = ($lastExecution.state -in @('InProgress', 'Pending')) -or
                    ($hasOpenExecution -and $status.code -notin @('Paused', 'NotConfigured'))

                # Quarantine details keep Graph's property names; only the timestamps are
                # converted to local time
                $quarantine = $status.quarantine
                if ($quarantine) {
                    $quarantineProperties = [ordered]@{}
                    foreach ($property in $quarantine.PSObject.Properties) {
                        $quarantineProperties[$property.Name] = if ($property.Name -in @('currentBegan', 'nextAttempt', 'seriesBegan')) {
                            ConvertTo-ECMA2LocalDateTime -Value $property.Value
                        }
                        else {
                            $property.Value
                        }
                    }
                    $quarantine = [PSCustomObject]$quarantineProperties
                }

                [PSCustomObject]@{
                    PSTypeName                 = 'ECMA2Host.SyncJob'
                    Id                          = $job.id
                    TemplateId                  = $job.templateId
                    ServicePrincipalId          = $ServicePrincipalId
                    ScheduleState               = $job.schedule.state
                    ScheduleInterval            = $job.schedule.interval
                    StatusCode                  = $status.code
                    IsRunning                   = [bool]$isRunning
                    LastExecutionState          = $lastExecution.state
                    LastExecutionTime           = $timeBegan
                    LastExecutionEndTime        = $timeEnded
                    LastSuccessfulExecutionTime = ConvertTo-ECMA2LocalDateTime -Value $status.lastSuccessfulExecution.timeEnded
                    SteadyStateLastAchievedTime = ConvertTo-ECMA2LocalDateTime -Value $status.steadyStateLastAchievedTime
                    Quarantine                  = $quarantine
                    EscrowCount                 = $lastExecution.countEscrowed
                    EscrowCountRaw              = $lastExecution.countEscrowedRaw
                    EscrowsPruned               = $status.escrowsPruned
                    ApiVersion                  = $ApiVersion
                }
            }
        }
        catch {
            Write-Error "Failed to get synchronization job for service principal '$ServicePrincipalId': $_"
        }
    }
}
