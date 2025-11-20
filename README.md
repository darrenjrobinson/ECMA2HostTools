# ECMA2HostTools PowerShell Module

A PowerShell module for orchestrating ECMA2Host and its connectors in Microsoft Entra ID OnPremises ECMA Application environments.

## Overview

This module provides a comprehensive set of cmdlets for managing the ECMA2Host service and its connectors, enabling automation of common administrative tasks such as starting/stopping services, monitoring run profiles, and managing connector configurations.

## Features

- **Service Management**: Start, stop, and monitor the ECMA2Host service
- **Connector Operations**: Manage connector lifecycle and status
- **Run Profile Monitoring**: Monitor connector run history and execution status
- **Configuration Management**: Export and import connector configurations
- **Remote Management**: Support for managing ECMA2Host on remote computers

## Installation

### Manual Installation

1. Copy the module folder to one of your PowerShell module paths:
   ```powershell
   $env:PSModulePath -split ';'
   ```

2. Common locations:
   - Current User: `$HOME\Documents\PowerShell\Modules`
   - All Users: `C:\Program Files\PowerShell\Modules`

3. Import the module:
   ```powershell
   Import-Module ECMA2HostTools
   ```

## Available Cmdlets

### Service Management
- `Start-ECMA2Host` - Starts the ECMA2Host service
- `Stop-ECMA2Host` - Stops the ECMA2Host service
- `Get-ECMA2HostStatus` - Gets the status of the ECMA2Host service

### Connector Management
- `Get-ECMA2Connector` - Gets ECMA2 connector information from Configuration.xml
- `Set-ECMA2Connector` - Updates ECMA2 connector parameters and settings
- `Get-ECMA2ConnectorSecret` - Decrypts encrypted parameters and secret tokens from connectors
- `Get-ECMA2ConnectorObjects` - Retrieves objects from a connector's cache using SCIM queries
- `Get-ECMA2ConnectorStatus` - Gets the status of an ECMA2 connector

### Run Profile Monitoring
- `Get-ECMA2ConnectorRunHistory` - Gets the run history for a connector

> **Note**: ECMA2Host does not provide an API or UI to manually trigger run profiles. Run profiles are automatically executed by Microsoft Entra provisioning service or by configured autosync timers on the connectors.

### Configuration Management
- `Export-ECMA2ConnectorConfiguration` - Exports a single connector configuration to JSON
- `Import-ECMA2ConnectorConfiguration` - Imports a connector from JSON and merges into Configuration.xml
- `Backup-ECMA2HostConfiguration` - Backs up the complete Configuration.xml (all connectors + host settings)
- `Restore-ECMA2HostConfiguration` - Restores a complete Configuration.xml backup

### Documentation
- `New-ECMA2ConnectorDocumentation` - Generates markdown documentation for connectors

## Usage Examples

### Start the ECMA2Host Service
```powershell
# Start or resume the service (requires Administrator privileges)
Start-ECMA2Host

# The cmdlet automatically detects if the service is paused and resumes it
# If stopped, it will start the service
```

### Stop the ECMA2Host Service
```powershell
# Stop the service (requires Administrator privileges)
Stop-ECMA2Host

# Force stop even if dependent services exist
Stop-ECMA2Host -Force
```

### Get Service Status
```powershell
# Check service status (no admin privileges required)
Get-ECMA2HostStatus

# Check status on remote computer
Get-ECMA2HostStatus -ComputerName "Server01"
```

### Get Connector Information
```powershell
# Get all connectors
Get-ECMA2Connector

# Get specific connector
Get-ECMA2Connector -Name "SQLConnector"

# Get connectors with wildcard
Get-ECMA2Connector -Name "AD*"

# Access connector properties
$connector = Get-ECMA2Connector -Name "SQLConnector"
$connector.RunProfiles
$connector.Parameters
$connector.AutosyncTimer
```

### Update Connector Configuration
```powershell
# Update a single parameter
Set-ECMA2Connector -Name "SQLConnector" -Parameters @{ 'Username' = 'newuser' }

# Update multiple parameters
Set-ECMA2Connector -Name "SQLConnector" -Parameters @{ 
    'Schema Script' = 'C:\Scripts\schema.ps1'
    'Import Script' = 'C:\Scripts\import.ps1'
}

# Update AutosyncTimer
Set-ECMA2Connector -Name "SQLConnector" -AutosyncTimer 300

# Preview changes without applying them
Set-ECMA2Connector -Name "SQLConnector" -Parameters @{ 'Username' = 'test' } -WhatIf
```

### Decrypt Connector Secrets
```powershell
# Decrypt encrypted parameters for a connector
# Displays all encrypted parameters in a readable format
Get-ECMA2ConnectorSecret -Name "SQLConnector"

# Output:
# Name                : SQLConnector
# EncryptedParameters :   Password:
#                           Name: Password
#                           Value: SecureP@ssw0rd123
#                           Use: Connectivity
# SecretToken         : 
# ComputerName        : ECMA2HOSTSERVER

# Include the connector's SecretToken (used for API authentication)
Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken

# Output with multiple encrypted parameters and SecretToken:
# Name                : APIConnector
# EncryptedParameters :   Password (auxiliary):
#                           Name: Password (auxiliary)
#                           Value: AuxiliaryP@ss123
#                           Use: Connectivity
#                         Password:
#                           Name: Password
#                           Value: a1b2c3d4-e5f6-7890-abcd-ef1234567890
#                           Use: Connectivity
# SecretToken         : 12345678-abcd-ef12-3456-7890abcdef12
# ComputerName        : ECMA2HOSTSERVER

# Access decrypted values programmatically
$secrets = Get-ECMA2ConnectorSecret -Name "SQLConnector"
$password = $secrets.EncryptedParameters['Password'].Value
Write-Host "Password: $password"

# With SecretToken
$secrets = Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken
$password = $secrets.EncryptedParameters['Password'].Value
$token = $secrets.SecretToken
Write-Host "Password: $password"
Write-Host "SecretToken: $token"

# List all encrypted parameters
$secrets = Get-ECMA2ConnectorSecret -Name "APIConnector"
$secrets.EncryptedParameters.Keys | ForEach-Object {
    $param = $secrets.EncryptedParameters[$_]
    Write-Host "$($param.Name): $($param.Value)"
}

# Note: Works in both PowerShell 7+ and Windows PowerShell 5.1
# In PowerShell 7+, automatically delegates to Windows PowerShell 5.1
# Must run on the same machine where ECMA2Host is installed (uses DPAPI LocalMachine scope)
```

### Check Connector Status
```powershell
# Get status of all connectors
Get-ECMA2ConnectorStatus

# Get status of specific connector
Get-ECMA2ConnectorStatus -Name "LDAPConnector"

# Get status with wildcard
Get-ECMA2ConnectorStatus -Name "SQL*"

# Check if connectors are ready
Get-ECMA2ConnectorStatus | Where-Object { $_.HealthStatus -ne 'Healthy' }

# View detailed status for a connector
Get-ECMA2ConnectorStatus -Name "SQLConnector" | Format-List
```

### Export and Import Connector Configuration
```powershell
# Export connector configuration
Export-ECMA2ConnectorConfiguration -ConnectorName "LDAPConnector" -Path "C:\Backup\LDAPConnector.json"

# Export with decrypted secrets (requires admin on ECMA2Host server)
Export-ECMA2ConnectorConfiguration -ConnectorName "LDAPConnector" -Path "C:\Backup\LDAPConnector-Full.json" -IncludeSecrets

# Force overwrite existing file
Export-ECMA2ConnectorConfiguration -ConnectorName "SQLConnector" -Path "C:\Backup\SQLConnector.json" -Force

# View export summary
$export = Export-ECMA2ConnectorConfiguration -ConnectorName "LDAPConnector" -Path "C:\Backup\LDAPConnector.json"
$export | Format-List

# Import connector configuration
Import-ECMA2ConnectorConfiguration -Path "C:\Backup\LDAPConnector.json" -ConnectorName "LDAPConnector-Restored"
```

### Get Run History
```powershell
# Get recent run history for all connectors
Get-ECMA2ConnectorRunHistory -Last 20

# Get run history for specific connector
Get-ECMA2ConnectorRunHistory -ConnectorName "SQLConnector" -Last 10

# Get run history for the last 24 hours
Get-ECMA2ConnectorRunHistory -StartTime (Get-Date).AddDays(-1)

# Filter by run profile
Get-ECMA2ConnectorRunHistory -ConnectorName "LDAPConnector" -RunProfile "RunFullCycle"

# Get detailed view with full messages
Get-ECMA2ConnectorRunHistory -ConnectorName "SQLConnector" -Last 5 | Format-List

# Get only errors and warnings
Get-ECMA2ConnectorRunHistory -MaxEvents 2000 | 
    Where-Object { $_.Status -in 'Error', 'Warning' } | 
    Select-Object TimeCreated, ConnectorName, RunProfile, Status, Message

# Show compact summary
Get-ECMA2ConnectorRunHistory -Last 50 | 
    Select-Object TimeCreated, ConnectorName, RunProfile, Status | 
    Format-Table -AutoSize
```

### Query Connector Objects

> **Important**: ECMA2Host filtering is limited to exact matches only. The `-FilterAttribute` and `-FilterValue` parameters only support the SCIM `eq` (equals) operator. Wildcard patterns, partial matching (starts with, ends with, contains), and other comparison operators are not supported by ECMA2Host.
>
> **Recommendation**: For complex filtering, retrieve a broader set of results using `-GetAll` and then use PowerShell's filtering capabilities (`Where-Object`, `-like`, `-match`, `-gt`, etc.) to find specific objects.

```powershell
# Get all objects from a connector (automatically retrieves all pages)
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2Connector -Name "LDAPConnector" | Get-ECMA2ConnectorObjects -SecretToken $secret -GetAll

# Combine cmdlets in pipeline to get objects with custom formatting
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2Connector -Name "LDAPConnector" | 
    Get-ECMA2ConnectorObjects -SecretToken $secret -GetAll | 
    Select-Object Id, @{N='Name';E={$_.ECMA2HostAttributes.displayName}}, @{N='Login';E={$_.ECMA2HostAttributes.userName}}

# Filter objects by exact attribute value (ECMA2Host only supports exact 'eq' matching)
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
    -FilterAttribute "id" -FilterValue "12345"

# Filter using full SCIM extension path (exact match only)
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
    -FilterAttribute "urn:ietf:params:scim:schemas:extension:ECMA2Host:2.0:User:id" -FilterValue "1"

# Use custom SCIM filter expression (only 'eq' operator supported)
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
    -CustomFilter 'name eq "John Smith"'

# RECOMMENDED: Get all objects and filter with PowerShell for partial matches
$secret = (Get-ECMA2ConnectorSecret -Name "SQLConnector" -IncludeSecretToken).SecretToken
$users = Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret -GetAll

# Find users by pattern matching
$users | Where-Object { $_.UserName -like "*admin*" }
$users | Where-Object { $_.DisplayName -like "*Smith*" }
$users | Where-Object { $_.ECMA2HostAttributes.employeeId -like "100*" }

# Complex filtering with multiple criteria
$users | Where-Object { 
    $_.Active -eq $true -and 
    $_.ECMA2HostAttributes.department -eq "IT" -and
    $_.UserName -match '^j'
}

# Numeric comparisons (not supported by ECMA2Host filters)
$users | Where-Object { $_.ECMA2HostAttributes.employeeId -gt 10000 }

# Get only the total count of objects (efficient for validation/monitoring)
$secret = (Get-ECMA2ConnectorSecret -Name "SQLConnector" -IncludeSecretToken).SecretToken
$count = Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret -CountOnly
Write-Host "Connector has $count objects"

# Use CountOnly for quick validation of multiple connectors
foreach ($connectorName in @('LDAPConnector', 'SQLConnector', 'APIConnector')) {
    $secret = (Get-ECMA2ConnectorSecret -Name $connectorName -IncludeSecretToken).SecretToken
    $count = Get-ECMA2ConnectorObjects -ConnectorName $connectorName -SecretToken $secret -CountOnly
    Write-Host "$connectorName has $count objects"
}

# Get specific page of results (without -GetAll, returns single page)
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
    -ItemsPerPage 10 -StartIndex 11

# Show detailed request/response for diagnostics
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
    -GetAll -ShowDetails -ItemsPerPage 5

# Access ECMA2Host-specific attributes from connector objects
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
$objects = Get-ECMA2Connector -Name "LDAPConnector" | 
    Get-ECMA2ConnectorObjects -SecretToken $secret -GetAll
$objects[0].ECMA2HostAttributes  # View all connector-specific attributes
$objects[0].RawObject  # View complete SCIM response object

# Note: Port defaults to 8585. For non-default ports, use -Port parameter:
# Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret -Port 9090 -GetAll
```

### Generate Connector Documentation
```powershell
# Generate documentation for a specific connector
Get-ECMA2Connector -Name "SQL*" | New-ECMA2ConnectorDocumentation -Path "C:\Docs\SQLConnector.md"

# Generate documentation for all connectors
New-ECMA2ConnectorDocumentation -Path "C:\Docs\AllConnectors.md"

# Output to pipeline (for viewing in console or further processing)
Get-ECMA2Connector -Name "LDAPConnector" | New-ECMA2ConnectorDocumentation

# Generate documentation with decrypted secrets (use with caution)
New-ECMA2ConnectorDocumentation -ConnectorName "LDAPConnector" -IncludeSecrets -Path "C:\Secure\LDAPConnector_Full.md"

# Generate documentation for multiple connectors matching a pattern
New-ECMA2ConnectorDocumentation -ConnectorName "AD*" -Path "C:\Docs\AD_Connectors.md"

# View documentation summary
$doc = Get-ECMA2Connector | New-ECMA2ConnectorDocumentation -Path "C:\Docs\All.md"
$doc | Format-List
```

### Backup and Restore Configuration
```powershell
# Backup complete ECMA2Host configuration (all connectors + host settings)
Backup-ECMA2HostConfiguration -Path "C:\Backups\ECMA2Host_$(Get-Date -Format 'yyyyMMdd').xml"

# Restore complete configuration
Restore-ECMA2HostConfiguration -Path "C:\Backups\ECMA2Host_20250117.xml"

# Restore and restart service automatically
Restore-ECMA2HostConfiguration -Path "C:\Backups\ECMA2Host_20250117.xml" -RestartService -Force

# View backup summary
$backup = Backup-ECMA2HostConfiguration -Path "C:\Backups\Full.xml"
$backup | Format-List
```

## Requirements

- PowerShell 5.1 or later (PowerShell 7+ supported with automatic fallback for decryption)
- ECMA2Host installed on the target system
- **Administrator privileges required** for service management operations (Start/Stop/Resume)
- Appropriate permissions to manage services and connectors
- **Secret decryption must run on the same machine** where ECMA2Host is installed

## Development Status

**Implemented Functions:**
- ✅ `Get-ECMA2Connector` - Fully implemented, reads from Configuration.xml
- ✅ `Set-ECMA2Connector` - Fully implemented, updates Configuration.xml with backup support
- ✅ `Get-ECMA2ConnectorSecret` - Fully implemented, decrypts passwords and tokens (PS7+ and PS5.1 compatible)
- ✅ `Get-ECMA2ConnectorObjects` - Fully implemented, queries connector cache using SCIM protocol
- ✅ `Get-ECMA2ConnectorStatus` - Fully implemented, shows connector operational status
- ✅ `Get-ECMA2ConnectorRunHistory` - Fully implemented, retrieves run history from ECMA2Host event log
- ✅ `Export-ECMA2ConnectorConfiguration` - Fully implemented, exports connector config to JSON
- ✅ `Import-ECMA2ConnectorConfiguration` - Fully implemented, imports connector from JSON and merges into Configuration.xml
- ✅ `Backup-ECMA2HostConfiguration` - Fully implemented, backs up complete Configuration.xml
- ✅ `Restore-ECMA2HostConfiguration` - Fully implemented, restores complete Configuration.xml with automatic backup
- ✅ `New-ECMA2ConnectorDocumentation` - Fully implemented, generates markdown documentation for connectors
- ✅ `Get-ECMA2HostStatus` - Fully implemented with PowerShell 5.1 compatibility
- ✅ `Start-ECMA2Host` - Fully implemented with pause/resume support, requires Administrator
- ✅ `Stop-ECMA2Host` - Fully implemented with force option, requires Administrator

## Author

**Darren J Robinson**
- GitHub: [darrenjrobinson](https://github.com/darrenjrobinson)
- Blog: [blog.darrenjrobinson.com](https://blog.darrenjrobinson.com/)

## Contributing

When extending this module:
- Follow PowerShell best practices and naming conventions
- Use approved PowerShell verbs
- Include comprehensive comment-based help
- Add proper parameter validation
- Include verbose and debug output
- Follow PSScriptAnalyzer rules
- Add Pester tests for new functions

## License

Copyright (c) 2025 Darren J Robinson. All rights reserved.

## Support

For issues or questions, please visit [blog.darrenjrobinson.com](https://blog.darrenjrobinson.com/) or check the GitHub repository.
