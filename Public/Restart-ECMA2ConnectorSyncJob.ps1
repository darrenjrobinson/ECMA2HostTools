function Restart-ECMA2ConnectorSyncJob {
    <#
    .SYNOPSIS
        Restarts a Microsoft Entra cloud provisioning synchronization job, optionally resetting escrows and other state.

    .DESCRIPTION
        Calls the Microsoft Graph synchronizationJob restart action to clear stuck
        provisioning state - most commonly to reset escrows (retry provisioning
        failures), but supports every documented resetScope value: Escrows, Watermark,
        QuarantineState, ForceDeletes, Full, None, and ConnectorDataStore.

        This is a destructive, high-impact operation with two safety guards:
        - 'None' and 'ConnectorDataStore' are flagged by Microsoft as "do not use
          without guidance" (None: use Start-ECMA2ConnectorSyncJob instead;
          ConnectorDataStore: contact Microsoft Support) and are blocked unless
          -Force is specified.
        - If the job's last run is still in progress, only a 'Full' reset (or -Force)
          is allowed - a narrower reset such as Escrows should wait for the run to
          finish, while a Full reset is the deliberate abort-and-recover path.

        Requires a prior Connect-ECMA2Graph with Synchronization.ReadWrite.All.

    .PARAMETER ServicePrincipalId
        The object ID of the service principal (enterprise application) the job belongs to.

    .PARAMETER JobId
        The synchronization job identifier to restart.

    .PARAMETER ResetScope
        One or more reset scopes to apply. Defaults to 'Escrows'. See
        https://learn.microsoft.com/en-us/graph/api/resources/synchronization-synchronizationjobrestartcriteria
        for details of each value.

    .PARAMETER ApiVersion
        The Microsoft Graph API version to call. Defaults to v1.0.

    .PARAMETER Force
        Required to select 'None' or 'ConnectorDataStore', and to bypass the
        currently-running-job guard for a non-Full reset.

    .PARAMETER PassThru
        Return the job's status after the restart completes.

    .EXAMPLE
        Restart-ECMA2ConnectorSyncJob -ServicePrincipalId $spId -JobId $jobId
        Resets escrows (the default) - retries previously failed provisioning operations.

    .EXAMPLE
        Restart-ECMA2ConnectorSyncJob -ServicePrincipalId $spId -JobId $jobId -ResetScope Full
        Full restart - can be used to abort a stuck/in-progress run and recover.

    .EXAMPLE
        Restart-ECMA2ConnectorSyncJob -ServicePrincipalId $spId -JobId $jobId -WhatIf
        Preview the action without calling Microsoft Graph.

    .NOTES
        Confirmation is required by default (ConfirmImpact = High). Use -WhatIf to preview.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$JobId,

        [Parameter()]
        [ValidateSet('Escrows', 'Watermark', 'QuarantineState', 'ForceDeletes', 'Full', 'None', 'ConnectorDataStore')]
        [string[]]$ResetScope = @('Escrows'),

        [Parameter()]
        [ValidateSet('v1.0', 'beta')]
        [string]$ApiVersion = 'v1.0',

        [Parameter()]
        [switch]$Force,

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

            $dangerousScopes = @('None', 'ConnectorDataStore')
            $requestedDangerous = $ResetScope | Where-Object { $_ -in $dangerousScopes }
            if ($requestedDangerous -and -not $Force) {
                Write-Error "ResetScope '$($requestedDangerous -join ', ')' is flagged by Microsoft as 'do not use without guidance' (None: use Start-ECMA2ConnectorSyncJob instead; ConnectorDataStore: contact Microsoft Support). Pass -Force to proceed anyway."
                return
            }

            $isFullReset = 'Full' -in $ResetScope
            if ($currentJob.IsRunning -and -not $isFullReset -and -not $Force) {
                Write-Error "Synchronization job '$JobId' is currently running (LastExecutionState: $($currentJob.LastExecutionState)). A narrow reset ('$($ResetScope -join ', ')') should wait for the run to finish - wait for completion, pass -ResetScope Full to abort and recover, or pass -Force to override."
                return
            }
            if ($currentJob.IsRunning -and $isFullReset) {
                Write-Warning "Synchronization job '$JobId' is currently running - this Full reset will abort the in-progress synchronization cycle."
            }

            $resetScopeValue = $ResetScope -join ','
            $uri = if ($ApiVersion -eq 'beta') {
                "https://graph.microsoft.com/beta/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$JobId/microsoft.graph.restart"
            }
            else {
                "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$JobId/restart"
            }

            $target = "$JobId (ServicePrincipal $ServicePrincipalId)"
            $action = "Restart synchronization job with ResetScope '$resetScopeValue' (current status: $($currentJob.StatusCode), LastExecutionState: $($currentJob.LastExecutionState))"

            if ($PSCmdlet.ShouldProcess($target, $action)) {
                Invoke-ECMA2GraphRequest -Method POST -Uri $uri -Body @{ criteria = @{ resetScope = $resetScopeValue } } | Out-Null

                $result = [PSCustomObject]@{
                    PSTypeName         = 'ECMA2Host.SyncJobRestart'
                    ServicePrincipalId = $ServicePrincipalId
                    JobId              = $JobId
                    ResetScope         = $resetScopeValue
                    ApiVersion         = $ApiVersion
                    RestartedAt        = Get-Date
                }

                if ($PassThru) {
                    $result | Add-Member -MemberType NoteProperty -Name 'CurrentJob' -Value (Get-ECMA2ConnectorSyncJob -ServicePrincipalId $ServicePrincipalId -JobId $JobId -ApiVersion $ApiVersion)
                }

                Write-Verbose "Restarted synchronization job '$JobId' with ResetScope '$resetScopeValue'"
                return $result
            }
        }
        catch {
            Write-Error "Failed to restart synchronization job '$JobId': $_"
        }
    }
}
