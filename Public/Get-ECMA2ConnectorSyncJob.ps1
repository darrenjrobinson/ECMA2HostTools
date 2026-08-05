function Get-ECMA2ConnectorSyncJob {
    <#
    .SYNOPSIS
        Gets Microsoft Entra cloud provisioning synchronization job details for a service principal.

    .DESCRIPTION
        Retrieves one or all synchronization jobs for the given service principal
        (enterprise application), including schedule and status - including whether
        the job's last run is still in progress, and any active quarantine/escrows.
        Use this to confirm the correct servicePrincipalId/jobId, and current state,
        before calling Restart-ECMA2ConnectorSyncJob.

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
                [PSCustomObject]@{
                    PSTypeName         = 'ECMA2Host.SyncJob'
                    Id                 = $job.id
                    TemplateId         = $job.templateId
                    ServicePrincipalId = $ServicePrincipalId
                    ScheduleState      = $job.schedule.state
                    ScheduleInterval   = $job.schedule.interval
                    StatusCode         = $job.status.code
                    IsRunning          = ($job.status.lastExecution.state -in @('InProgress', 'Pending'))
                    LastExecutionState = $job.status.lastExecution.state
                    LastExecutionTime  = $job.status.lastExecution.timeBegan
                    Quarantine         = $job.status.quarantine
                    Escrows            = $job.status.escrows
                    ApiVersion         = $ApiVersion
                }
            }
        }
        catch {
            Write-Error "Failed to get synchronization job for service principal '$ServicePrincipalId': $_"
        }
    }
}
