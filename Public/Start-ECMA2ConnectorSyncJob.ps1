function Start-ECMA2ConnectorSyncJob {
    <#
    .SYNOPSIS
        Starts (or resumes) a Microsoft Entra cloud provisioning synchronization job.

    .DESCRIPTION
        Calls the Microsoft Graph synchronizationJob start action. If the job is
        paused, it continues processing changes from the point where it was
        paused. If the job is in quarantine, the quarantine status is cleared.

        Microsoft recommends not scripting continuous calls to Start while a job
        is already running - use it only when the job is currently paused or in
        quarantine.

        Requires a prior Connect-ECMA2Graph with Synchronization.ReadWrite.All.

    .PARAMETER ServicePrincipalId
        The object ID of the service principal (enterprise application) the job belongs to.

    .PARAMETER JobId
        The synchronization job identifier to start.

    .PARAMETER ApiVersion
        The Microsoft Graph API version to call. Defaults to v1.0.

    .PARAMETER PassThru
        Return the job's status after the start completes.

    .EXAMPLE
        Start-ECMA2ConnectorSyncJob -ServicePrincipalId $spId -JobId $jobId
        Resumes a paused job, or clears quarantine on a quarantined job.

    .EXAMPLE
        Start-ECMA2ConnectorSyncJob -ServicePrincipalId $spId -JobId $jobId -WhatIf
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

            if ($currentJob.IsRunning) {
                Write-Warning "Synchronization job '$JobId' is already running (LastExecutionState: $($currentJob.LastExecutionState)) - Microsoft recommends against calling Start on an already-running job. Proceeding anyway."
            }

            $uri = if ($ApiVersion -eq 'beta') {
                "https://graph.microsoft.com/beta/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$JobId/microsoft.graph.start"
            }
            else {
                "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$JobId/start"
            }

            $target = "$JobId (ServicePrincipal $ServicePrincipalId)"
            $action = "Start synchronization job (current status: $($currentJob.StatusCode), LastExecutionState: $($currentJob.LastExecutionState))"

            if ($PSCmdlet.ShouldProcess($target, $action)) {
                Invoke-ECMA2GraphRequest -Method POST -Uri $uri | Out-Null

                $result = [PSCustomObject]@{
                    PSTypeName         = 'ECMA2Host.SyncJobStart'
                    ServicePrincipalId = $ServicePrincipalId
                    JobId              = $JobId
                    ApiVersion         = $ApiVersion
                    StartedAt          = Get-Date
                }

                if ($PassThru) {
                    $result | Add-Member -MemberType NoteProperty -Name 'CurrentJob' -Value (Get-ECMA2ConnectorSyncJob -ServicePrincipalId $ServicePrincipalId -JobId $JobId -ApiVersion $ApiVersion)
                }

                Write-Verbose "Started synchronization job '$JobId'"
                return $result
            }
        }
        catch {
            Write-Error "Failed to start synchronization job '$JobId': $_"
        }
    }
}
