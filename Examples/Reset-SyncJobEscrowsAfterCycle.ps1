<#
.SYNOPSIS
    Waits for one or more cloud provisioning synchronization jobs to finish their current
    cycle, then resets escrows - suitable for interactive testing or an unattended
    Scheduled Task using app-only authentication.

.DESCRIPTION
    Connects to Microsoft Graph (interactively via device code by default, or app-only
    via a client secret or certificate for unattended runs), then watches one or more
    service principals' synchronization jobs for an actual completed cycle: either a
    run that was already in progress finishing, or a new run starting and finishing
    while this script is watching. Once that witnessed completion happens, the script
    waits an additional settling period before resetting escrows, so any in-flight
    escrow writes have time to finish before they're cleared.

    Sync jobs run on a schedule (e.g. every 40 minutes) and are idle between cycles far
    more often than they're actively running. Because of that, "not currently running"
    is NOT by itself treated as "a cycle just completed" - by default the script waits
    for a genuine transition (running -> finished, or the job's last-run timestamp
    advancing past the point where this script started watching it) before starting the
    settle timer. Use -TrustAlreadyIdle to opt back into the simpler "it's idle right
    now, that's good enough" behavior for ad-hoc runs where you already know a job just
    finished (e.g. you just watched it complete on a dashboard) and don't want to wait
    for the next full interval.

    A single application can be targeted with -ServicePrincipalId (optionally -JobId).
    Multiple applications can be processed in one run via -ConfigPath, pointing to a
    JSON file of the form:

        [
          { "ServicePrincipalId": "11111111-1111-1111-1111-111111111111" },
          { "ServicePrincipalId": "22222222-2222-2222-2222-222222222222", "JobId": "job1" },
          { "ServicePrincipalId": "33333333-3333-3333-3333-333333333333", "ResetScope": ["Full"] }
        ]

    All applications are polled together (one pass per -PollIntervalSeconds), not one
    at a time, so total run time is roughly the slowest single application's wait, not
    the sum of all of them. One application failing or timing out does not stop the
    others - a per-application status summary is printed and returned at the end.

    If -JobId (or an entry's JobId in -ConfigPath) is not supplied, the script looks up
    that service principal's sync job(s) automatically: if there is exactly one, it is
    used; if there is more than one, that application is marked Errored and the job IDs
    found are listed, asking you to specify -JobId explicitly rather than guessing.

.PARAMETER ServicePrincipalId
    The object ID of a single service principal (enterprise application) to process.
    Ignored if -ConfigPath is supplied.

.PARAMETER JobId
    The synchronization job identifier to watch and reset for -ServicePrincipalId.
    Optional - auto-discovered when the service principal has exactly one synchronization job.

.PARAMETER ConfigPath
    Path to a JSON file listing multiple applications to process in a single run. See
    .DESCRIPTION for the file shape. Takes priority over -ServicePrincipalId when both are supplied.

.PARAMETER ResetScope
    The reset scope(s) to apply once a job's cycle completes. Defaults to 'Escrows'.
    Can be overridden per application in -ConfigPath.

.PARAMETER TenantId
    The tenant ID or verified domain to authenticate against. Forwarded to Connect-ECMA2Graph.
    Defaults to 'organizations' (resolves to the signed-in user's home tenant in Interactive mode).

.PARAMETER AuthMode
    How to authenticate to Microsoft Graph:
    - Interactive (default): device code flow - the same sign-in experience as Graph Explorer.
      Requires a human to complete sign-in; not suitable for an unattended Scheduled Task.
    - ClientSecret: app-only auth using -ClientId and -ClientSecret.
    - Certificate: app-only auth using -ClientId and -CertificateThumbprint (or -Certificate).
    ClientSecret and Certificate are the two options suitable for unattended/scheduled runs.

.PARAMETER ClientId
    The application (client) ID to authenticate as. Required for -AuthMode ClientSecret or Certificate.

.PARAMETER ClientSecret
    The application's client secret, as a SecureString. Required for -AuthMode ClientSecret.

.PARAMETER CertificateThumbprint
    Thumbprint of a certificate (with private key) in Cert:\CurrentUser\My or
    Cert:\LocalMachine\My. Used for -AuthMode Certificate if -Certificate isn't supplied.

.PARAMETER Certificate
    An X509Certificate2 (with private key) to authenticate with. Used for -AuthMode Certificate.

.PARAMETER PollIntervalSeconds
    How often to re-check jobs that are still running. Defaults to 60 seconds.

.PARAMETER WaitAfterCompletionMinutes
    How long to wait after a job's cycle completes before resetting its escrows. Defaults to 5 minutes.

.PARAMETER TimeoutMinutes
    Safety cap on how long to poll for jobs to finish before giving up (per run, not per
    application) - any application still running past this is marked TimedOut and is not
    reset. Defaults to 120 minutes.

.PARAMETER LogPath
    Optional path to a log file. If supplied, every status line is appended (timestamped)
    to this file in addition to being written to the console - useful since Task Scheduler
    does not capture console output.

.PARAMETER TrustAlreadyIdle
    Treat a job that is simply not running right now as having "completed a cycle,"
    starting the settle timer immediately instead of waiting to witness an actual
    run/finish transition. Off by default - see .DESCRIPTION for why. Applies to every
    application in the run (not selectable per-app in -ConfigPath).

.EXAMPLE
    .\Reset-SyncJobEscrowsAfterCycle.ps1 -ServicePrincipalId $spId
    Interactive single-application run: connects via device code, auto-discovers the job,
    waits for its current cycle to finish, waits 5 more minutes, then resets escrows.

.EXAMPLE
    .\Reset-SyncJobEscrowsAfterCycle.ps1 -ConfigPath 'C:\Scripts\apps.json' `
        -AuthMode Certificate -TenantId $tenantId -ClientId $appId -CertificateThumbprint $thumbprint `
        -LogPath 'C:\Scripts\Logs\reset-escrows.log'
    Unattended multi-application run suitable for a Scheduled Task, authenticating with a certificate.

.EXAMPLE
    .\Reset-SyncJobEscrowsAfterCycle.ps1 -ConfigPath 'C:\Scripts\apps.json' `
        -AuthMode ClientSecret -TenantId $tenantId -ClientId $appId `
        -ClientSecret (Get-Content 'C:\Scripts\clientsecret.txt' | ConvertTo-SecureString)
    Unattended multi-application run authenticating with a client secret stored at rest as a
    DPAPI-protected SecureString (see ESCROW Automation.md for how to generate that file).

.NOTES
    Resetting escrows is a High-impact operation on Restart-ECMA2ConnectorSyncJob. This
    script suppresses its confirmation prompt (-Confirm:$false) since it is designed to
    run unattended after a potentially long wait - the cmdlet's own dangerous-scope and
    running-job guards still apply underneath.

    -TrustAlreadyIdle is a switch - pass it bare (-TrustAlreadyIdle) to enable it, or with a
    colon (-TrustAlreadyIdle:$true / -TrustAlreadyIdle:$false) if you need to set it
    explicitly from a variable. Do NOT write "-TrustAlreadyIdle $true" with a space - for a
    switch parameter that binds $true as a separate, unrelated positional argument instead
    (only -ServicePrincipalId is positional in this script), which silently ends up in the
    wrong parameter rather than raising an obvious error.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ServicePrincipalId,

    [Parameter()]
    [string]$JobId,

    [Parameter()]
    [string]$ConfigPath,

    [Parameter()]
    [string[]]$ResetScope = @('Escrows'),

    [Parameter()]
    [string]$TenantId = 'organizations',

    [Parameter()]
    [ValidateSet('Interactive', 'ClientSecret', 'Certificate')]
    [string]$AuthMode = 'Interactive',

    [Parameter()]
    [string]$ClientId,

    [Parameter()]
    [SecureString]$ClientSecret,

    [Parameter()]
    [string]$CertificateThumbprint,

    [Parameter()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

    [Parameter()]
    [int]$PollIntervalSeconds = 60,

    [Parameter()]
    [int]$WaitAfterCompletionMinutes = 5,

    [Parameter()]
    [int]$TimeoutMinutes = 120,

    [Parameter()]
    [string]$LogPath,

    [Parameter()]
    [switch]$TrustAlreadyIdle
)

# Import the module if not already loaded
if (-not (Get-Module -Name ECMA2HostTools)) {
    Import-Module ECMA2HostTools -ErrorAction Stop
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$ForegroundColor = 'Gray'
    )

    Write-Host $Message -ForegroundColor $ForegroundColor

    if ($LogPath) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message" | Add-Content -Path $LogPath
    }
}

function ConvertFrom-JsonArraySafe {
    # ConvertFrom-Json on some Windows PowerShell 5.1 builds silently mis-parses a JSON
    # array of multiple objects - collapsing them into a single PSCustomObject whose
    # properties become arrays of the per-object values, instead of returning one object
    # per array element (reproduced consistently on this module's target PS version).
    # Parsing each top-level {...} object individually avoids the bug entirely, since a
    # single isolated JSON object always parses correctly.
    param(
        [Parameter(Mandatory)]
        [string]$Json
    )

    $trimmed = $Json.Trim()
    if (-not $trimmed.StartsWith('[') -or -not $trimmed.EndsWith(']')) {
        throw "Expected a top-level JSON array."
    }

    $inner = $trimmed.Substring(1, $trimmed.Length - 2).Trim()
    if (-not $inner) {
        return @()
    }

    $objectTexts = [regex]::Split($inner, '(?<=\})\s*,\s*(?=\{)')
    foreach ($objectText in $objectTexts) {
        $objectText | ConvertFrom-Json
    }
}

# Infer -AuthMode from whichever credential parameters were actually supplied, unless
# -AuthMode was passed explicitly - otherwise passing -CertificateThumbprint/-ClientSecret
# without also remembering -AuthMode would silently fall back to Interactive device code.
if (-not $PSBoundParameters.ContainsKey('AuthMode')) {
    if ($CertificateThumbprint -or $Certificate) {
        $AuthMode = 'Certificate'
    }
    elseif ($ClientSecret) {
        $AuthMode = 'ClientSecret'
    }
}

# Validate the auth parameters up front for the selected -AuthMode
switch ($AuthMode) {
    'ClientSecret' {
        if (-not $ClientId -or -not $ClientSecret) {
            Write-Error "-AuthMode ClientSecret requires both -ClientId and -ClientSecret."
            return
        }
    }
    'Certificate' {
        if (-not $ClientId) {
            Write-Error "-AuthMode Certificate requires -ClientId."
            return
        }
        if (-not $CertificateThumbprint -and -not $Certificate) {
            Write-Error "-AuthMode Certificate requires -CertificateThumbprint or -Certificate."
            return
        }
    }
}

# Build the list of applications to process
$appDefinitions = @()

if ($ConfigPath) {
    if (-not (Test-Path -Path $ConfigPath)) {
        Write-Error "Config file not found at: $ConfigPath"
        return
    }

    try {
        $configEntries = @(ConvertFrom-JsonArraySafe -Json (Get-Content -Path $ConfigPath -Raw))
    }
    catch {
        Write-Error "Failed to parse -ConfigPath '$ConfigPath' as JSON: $_"
        return
    }

    foreach ($entry in $configEntries) {
        if (-not $entry.ServicePrincipalId) {
            Write-Warning "Skipping a -ConfigPath entry with no ServicePrincipalId."
            continue
        }

        $appDefinitions += [PSCustomObject]@{
            ServicePrincipalId = $entry.ServicePrincipalId
            JobId              = $entry.JobId
            ResetScope         = if ($entry.ResetScope) { @($entry.ResetScope) } else { $ResetScope }
        }
    }
}
elseif ($ServicePrincipalId) {
    $appDefinitions += [PSCustomObject]@{
        ServicePrincipalId = $ServicePrincipalId
        JobId              = $JobId
        ResetScope         = $ResetScope
    }
}
else {
    Write-Error "Specify -ServicePrincipalId for a single application, or -ConfigPath for multiple applications."
    return
}

if ($appDefinitions.Count -eq 0) {
    Write-Error "No valid applications to process."
    return
}

try {
    # Connect to Microsoft Graph using the selected auth mode
    $connectParams = @{ TenantId = $TenantId }
    switch ($AuthMode) {
        'Interactive' {
            Write-Log "Connecting to Microsoft Graph (device code sign-in)..." -ForegroundColor Cyan
        }
        'ClientSecret' {
            Write-Log "Connecting to Microsoft Graph (app-only, client secret)..." -ForegroundColor Cyan
            $connectParams['ClientId'] = $ClientId
            $connectParams['ClientSecret'] = $ClientSecret
        }
        'Certificate' {
            Write-Log "Connecting to Microsoft Graph (app-only, certificate)..." -ForegroundColor Cyan
            $connectParams['ClientId'] = $ClientId
            if ($Certificate) { $connectParams['Certificate'] = $Certificate }
            else { $connectParams['CertificateThumbprint'] = $CertificateThumbprint }
        }
    }
    Connect-ECMA2Graph @connectParams | Out-Null

    # Build the per-application working state: Pending -> Settling -> Done / Errored / TimedOut
    $apps = foreach ($def in $appDefinitions) {
        [PSCustomObject]@{
            ServicePrincipalId    = $def.ServicePrincipalId
            JobId                 = $def.JobId
            ResetScope            = $def.ResetScope
            Status                = 'Pending'
            SettleUntil           = $null
            Detail                = $null
            BaselineExecutionTime = $null
            HasBeenSeenRunning    = $false
            BaselineCaptured      = $false
        }
    }

    # Resolve any missing JobId up front via auto-discovery; isolate failures per application
    foreach ($app in $apps) {
        if ($app.JobId) { continue }

        Write-Log "No JobId supplied for service principal '$($app.ServicePrincipalId)', looking up its synchronization job(s)..." -ForegroundColor Cyan
        $jobs = @(Get-ECMA2ConnectorSyncJob -ServicePrincipalId $app.ServicePrincipalId -WarningAction SilentlyContinue)

        if ($jobs.Count -eq 0) {
            $app.Status = 'Errored'
            $app.Detail = "No synchronization jobs found for service principal '$($app.ServicePrincipalId)'."
            Write-Log $app.Detail -ForegroundColor Red
        }
        elseif ($jobs.Count -gt 1) {
            $app.Status = 'Errored'
            $app.Detail = "Service principal '$($app.ServicePrincipalId)' has more than one synchronization job ($($jobs.Id -join ', ')). Specify JobId explicitly."
            Write-Log $app.Detail -ForegroundColor Red
        }
        else {
            $app.JobId = $jobs[0].Id
            $app.BaselineExecutionTime = $jobs[0].LastExecutionTime
            $app.HasBeenSeenRunning = $jobs[0].IsRunning
            $app.BaselineCaptured = $true
            Write-Log "Using synchronization job '$($app.JobId)' for service principal '$($app.ServicePrincipalId)'" -ForegroundColor Green
        }
    }

    # Capture a baseline last-execution marker for apps whose JobId was already known up front
    # (the auto-discovery branch above already captured it as a side effect of finding the job)
    # - this is what lets the poll loop tell "already idle when we started watching" apart from
    # "actually finished a cycle while we were watching."
    foreach ($app in ($apps | Where-Object { $_.Status -eq 'Pending' -and -not $_.BaselineCaptured })) {
        $job = Get-ECMA2ConnectorSyncJob -ServicePrincipalId $app.ServicePrincipalId -JobId $app.JobId
        $app.BaselineExecutionTime = $job.LastExecutionTime
        $app.HasBeenSeenRunning = $job.IsRunning
        $app.BaselineCaptured = $true
    }

    # Poll all applications together until every one reaches a terminal state, capped by -TimeoutMinutes
    $timeoutAt = (Get-Date).AddMinutes($TimeoutMinutes)

    while ($apps | Where-Object { $_.Status -in @('Pending', 'Settling') }) {
        if ((Get-Date) -ge $timeoutAt) {
            foreach ($app in ($apps | Where-Object { $_.Status -in @('Pending', 'Settling') })) {
                $app.Status = 'TimedOut'
                $app.Detail = "Timed out after $TimeoutMinutes minute(s) waiting for its cycle to finish. Escrows were not reset."
                Write-Log "Job '$($app.JobId)' on '$($app.ServicePrincipalId)': $($app.Detail)" -ForegroundColor Red
            }
            break
        }

        foreach ($app in ($apps | Where-Object { $_.Status -eq 'Pending' })) {
            $job = Get-ECMA2ConnectorSyncJob -ServicePrincipalId $app.ServicePrincipalId -JobId $app.JobId

            if ($job.IsRunning) {
                $app.HasBeenSeenRunning = $true
                Write-Log "Job '$($app.JobId)' on '$($app.ServicePrincipalId)' is still running (LastExecutionState: $($job.LastExecutionState))." -ForegroundColor Yellow
                continue
            }

            # Not running - but that alone doesn't mean a cycle just completed, since a
            # periodically-scheduled job is idle between runs far more than it's active. Only
            # treat this as a witnessed completion if: we saw it running earlier and it has now
            # finished, or its last-run timestamp has moved past the baseline captured when we
            # started watching it (a full run happened and finished between two polls, missing
            # the "running" instant entirely). -TrustAlreadyIdle skips this check entirely.
            $newCycleWitnessed = $TrustAlreadyIdle -or $app.HasBeenSeenRunning -or ($job.LastExecutionTime -ne $app.BaselineExecutionTime)

            if ($newCycleWitnessed) {
                $app.Status = 'Settling'
                $app.SettleUntil = (Get-Date).AddMinutes($WaitAfterCompletionMinutes)
                Write-Log "Job '$($app.JobId)' on '$($app.ServicePrincipalId)' cycle completed (LastExecutionState: $($job.LastExecutionState)). Waiting $WaitAfterCompletionMinutes minute(s) before resetting escrows..." -ForegroundColor Green
            }
            else {
                Write-Log "Job '$($app.JobId)' on '$($app.ServicePrincipalId)' is idle - no new sync cycle observed yet since this run started watching it. Waiting for the next cycle to start..." -ForegroundColor Yellow
            }
        }

        foreach ($app in ($apps | Where-Object { $_.Status -eq 'Settling' -and (Get-Date) -ge $_.SettleUntil })) {
            try {
                Write-Log "Resetting ResetScope '$($app.ResetScope -join ',')' on job '$($app.JobId)' (service principal '$($app.ServicePrincipalId)')..." -ForegroundColor Cyan
                $result = Restart-ECMA2ConnectorSyncJob -ServicePrincipalId $app.ServicePrincipalId -JobId $app.JobId -ResetScope $app.ResetScope -Confirm:$false
                $app.Status = 'Done'
                $app.Detail = $result
                Write-Log "Job '$($app.JobId)' on '$($app.ServicePrincipalId)': escrows reset successfully." -ForegroundColor Green
            }
            catch {
                $app.Status = 'Errored'
                $app.Detail = $_.Exception.Message
                Write-Log "Job '$($app.JobId)' on '$($app.ServicePrincipalId)': failed to reset - $($app.Detail)" -ForegroundColor Red
            }
        }

        if ($apps | Where-Object { $_.Status -in @('Pending', 'Settling') }) {
            Start-Sleep -Seconds $PollIntervalSeconds
        }
    }

    Write-Log "`n===== Summary =====" -ForegroundColor Cyan
    $summary = $apps | Select-Object ServicePrincipalId, JobId, Status, Detail
    $summary | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log $_ }

    return $summary
}
catch {
    Write-Error "Reset-SyncJobEscrowsAfterCycle failed: $_"
}
finally {
    Disconnect-ECMA2Graph
}
