# Changelog

All notable changes to the ECMA2HostTools module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-11-17

### Fixed
- `Get-ECMA2ConnectorSyncJob` returned `LastExecutionTime` in UTC (or as a raw string on Windows PowerShell 5.1). Timestamps are now `DateTime` values in the system's local time zone
- `Get-ECMA2ConnectorSyncJob` always returned an empty `Escrows` property, because Microsoft Graph has no such property on the job status. The escrow count is now read from the job's last execution
- `Get-ECMA2ConnectorSyncJob` reported `IsRunning` as false while a cycle was in progress, because Microsoft Graph's `lastExecution.state` only reports a result (`Succeeded`, `Failed`, `EntryLevelErrors`). `IsRunning` is now also true when the last execution has a start time but no end time after it. This also affects the running-job guards in `Restart-ECMA2ConnectorSyncJob` and `Start-ECMA2ConnectorSyncJob`

### Added
- `Get-ECMA2ConnectorSyncJob` now returns `LastExecutionEndTime`, `LastSuccessfulExecutionTime`, `SteadyStateLastAchievedTime`, `EscrowCount`, `EscrowCountRaw` and `EscrowsPruned`

### Changed
- `Get-ECMA2ConnectorSyncJob` no longer returns the `Escrows` property (it never held data); use `EscrowCount` instead

## [1.2.1] - 2026-10-27

### Fixed
- `Connect-ECMA2Graph` device code sign-in could take minutes to show a code and then fail with `AADSTS70008` on hosts where IPv6 resolves but isn't routable. Every request opened a new HTTP connection and waited out the IPv6 attempts before falling back to IPv4, so polling stalled. `Connect-ECMA2Graph`, token refresh and Graph requests now share one web session per connection, so only the first connection pays the delay
- `Connect-ECMA2Graph` now warns when the device code request takes longer than 15 seconds, and names the registry setting that makes Windows prefer IPv4

## [1.2.0] - 2026-08-05

### Added
- `Pause-ECMA2ConnectorSyncJob` - pauses a cloud provisioning synchronization job (Microsoft Graph `pause` action); progress and job state are preserved for a later `Start-ECMA2ConnectorSyncJob`
- `Start-ECMA2ConnectorSyncJob` - starts/resumes a cloud provisioning synchronization job (Microsoft Graph `start` action); resumes a paused job from where it left off and clears quarantine if set

### Fixed
- `Connect-ECMA2Graph` device code sign-in now handles the `slow_down` response by backing off the polling interval instead of failing
- `Connect-ECMA2Graph -AccessToken` now reads the token's own `exp` claim (when it's a parseable JWT) to set `ExpiresOn`, instead of always guessing 60 minutes
- `Get-ECMA2GraphToken` no longer wipes out the cached refresh token when a `DeviceCode` refresh response omits `refresh_token`

## [1.1.0] - 2026-07-30

### Added
- `Connect-ECMA2Graph` / `Disconnect-ECMA2Graph` - Microsoft Graph authentication for cloud provisioning job management (interactive device code, app-only client secret, app-only certificate, or bring-your-own access token), implemented with raw REST calls so the module remains dependency-free
- `Get-ECMA2ConnectorSyncJob` - retrieves Microsoft Entra cloud provisioning synchronization job status for a service principal, including whether a run is currently in progress
- `Restart-ECMA2ConnectorSyncJob` - restarts a cloud provisioning synchronization job with a configurable `-ResetScope` (Escrows, Watermark, QuarantineState, ForceDeletes, Full, None, ConnectorDataStore), primarily to clear stuck escrows. Guards against the two Microsoft-flagged "do not use without guidance" reset scopes and against narrow resets while a job is still running, both requiring explicit `-Force` to override

### Note
- Module files are normally Authenticode-signed via `Sign-Module.ps1`; the current signing certificate has expired, so files touched in this release are unsigned pending a new certificate

## [1.0.0] - 2025-11-17

### Added
- Initial release of ECMA2HostTools module
- Basic module structure and scaffolding
