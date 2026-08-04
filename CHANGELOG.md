# Changelog

All notable changes to the ECMA2HostTools module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `Pause-ECMA2ConnectorSyncJob` - pauses a cloud provisioning synchronization job (Microsoft Graph `pause` action); progress and job state are preserved for a later `Start-ECMA2ConnectorSyncJob`
- `Start-ECMA2ConnectorSyncJob` - starts/resumes a cloud provisioning synchronization job (Microsoft Graph `start` action); resumes a paused job from where it left off and clears quarantine if set

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
