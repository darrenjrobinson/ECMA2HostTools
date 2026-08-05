function Pause-ECMA2ConnectorSyncJob {
    <#
    .SYNOPSIS
        Pauses a Microsoft Entra cloud provisioning synchronization job.

    .DESCRIPTION
        Calls the Microsoft Graph synchronizationJob pause action to temporarily
        stop a running job. All progress, including job state, is persisted, and
        the job continues from where it left off when Start-ECMA2ConnectorSyncJob
        is called.

        Requires a prior Connect-ECMA2Graph with Synchronization.ReadWrite.All.

    .PARAMETER ServicePrincipalId
        The object ID of the service principal (enterprise application) the job belongs to.

    .PARAMETER JobId
        The synchronization job identifier to pause.

    .PARAMETER ApiVersion
        The Microsoft Graph API version to call. Defaults to v1.0.

    .PARAMETER PassThru
        Return the job's status after the pause completes.

    .EXAMPLE
        Pause-ECMA2ConnectorSyncJob -ServicePrincipalId $spId -JobId $jobId
        Pauses the job - progress and state are preserved for a later Start.

    .EXAMPLE
        Pause-ECMA2ConnectorSyncJob -ServicePrincipalId $spId -JobId $jobId -WhatIf
        Preview the action without calling Microsoft Graph.

    .NOTES
        Confirmation is required by default (ConfirmImpact = Medium). Use -WhatIf to preview.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$JobId,

        [Parameter()]
        [ValidateSet('v1.0', 'beta')]
        [string]$ApiVersion = 'v1.0',

        [Parameter()]
        [switch]$PassThru
    )

    process {
        try {
            $currentJob = Get-ECMA2ConnectorSyncJob -ServicePrincipalId $ServicePrincipalId -JobId $JobId -ApiVersion $ApiVersion -WarningAction SilentlyContinue

            if (-not $currentJob) {
                Write-Error "Synchronization job '$JobId' not found for service principal '$ServicePrincipalId'. Confirm the ids with Get-ECMA2ConnectorSyncJob first."
                return
            }

            $uri = if ($ApiVersion -eq 'beta') {
                "https://graph.microsoft.com/beta/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$JobId/microsoft.graph.pause"
            }
            else {
                "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$JobId/pause"
            }

            $target = "$JobId (ServicePrincipal $ServicePrincipalId)"
            $action = "Pause synchronization job (current status: $($currentJob.StatusCode), LastExecutionState: $($currentJob.LastExecutionState))"

            if ($PSCmdlet.ShouldProcess($target, $action)) {
                Invoke-ECMA2GraphRequest -Method POST -Uri $uri | Out-Null

                $result = [PSCustomObject]@{
                    PSTypeName         = 'ECMA2Host.SyncJobPause'
                    ServicePrincipalId = $ServicePrincipalId
                    JobId              = $JobId
                    ApiVersion         = $ApiVersion
                    PausedAt           = Get-Date
                }

                if ($PassThru) {
                    $result | Add-Member -MemberType NoteProperty -Name 'CurrentJob' -Value (Get-ECMA2ConnectorSyncJob -ServicePrincipalId $ServicePrincipalId -JobId $JobId -ApiVersion $ApiVersion)
                }

                Write-Verbose "Paused synchronization job '$JobId'"
                return $result
            }
        }
        catch {
            Write-Error "Failed to pause synchronization job '$JobId': $_"
        }
    }
}
