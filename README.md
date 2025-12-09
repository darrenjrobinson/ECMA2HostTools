# ECMA2HostTools PowerShell Module

A PowerShell module for orchestrating ECMA2Host and its connectors in Microsoft Entra ID OnPremises ECMA Application environments.

## Overview

This module provides a comprehensive set of cmdlets for managing the ECMA2Host service and its connectors, enabling automation of common administrative tasks such as starting/stopping services, monitoring run profiles, and managing connector configurations.

## Features

- **Service Management**: Start, stop, and monitor the ECMA2Host service
- **Connector Operations**: Manage connector lifecycle and status
- **Run Profile Monitoring**: Monitor connector run history and execution status
- **Configuration Management**: Export and import connector configurations
- **Remote Management**: Query service status on remote computers and access remote configuration files via UNC paths or mapped drives

## Why Use ECMA2HostTools?

- **Simplified Authentication**: No need to manually manage secret tokens - the module automatically decrypts and retrieves them from your connector configuration
- **Query Connector Caches**: Directly query ECMA2Host connector caches using SCIM protocol without needing Microsoft Entra provisioning service
- **Real-time Monitoring**: Get live connector status, run history, and object counts to monitor provisioning operations
- **Automation-Ready**: Automate connector management, validation, and reporting tasks with PowerShell scripts
- **Comprehensive Object Access**: Retrieve, filter, and analyze connector objects with full attribute access and PowerShell filtering capabilities
- **Configuration Management**: Easily backup, export, import, and restore connector configurations for disaster recovery or environment migrations
- **Self-Service Diagnostics**: Troubleshoot connector issues without requiring access to the ECMA2Host Configuration Wizard

## Installation

### Recommended: PowerShell Gallery

Install directly from the PowerShell Gallery (recommended method):

```powershell
# Install for current user
Install-Module -Name ECMA2HostTools -Scope CurrentUser

# Install for all users (requires Administrator)
Install-Module -Name ECMA2HostTools -Scope AllUsers

# Import the module
Import-Module ECMA2HostTools
```

### Download from GitHub

Download the source code from GitHub:

1. Visit the [repository](https://github.com/darrenjrobinson/ECMA2HostTools)
2. Click the green **Code** button
3. Select **Download ZIP**
4. Extract the ZIP file to a temporary location
5. Continue with Manual Installation steps below

Or clone the repository:

```powershell
# Clone the repository
git clone https://github.com/darrenjrobinson/ECMA2HostTools.git
cd ECMA2HostTools
```

### Manual Installation

1. Copy the module folder to one of your PowerShell module paths:
   ```powershell
   $env:PSModulePath -split ';'
   ```

2. Common locations:
   - Current User: `$HOME\Documents\PowerShell\Modules\ECMA2HostTools`
   - All Users: `C:\Program Files\PowerShell\Modules\ECMA2HostTools`

3. Example manual installation:
   ```powershell
   # Copy to current user modules folder
   $modulePath = "$HOME\Documents\PowerShell\Modules\ECMA2HostTools"
   Copy-Item -Path ".\ECMA2HostTools" -Destination $modulePath -Recurse -Force
   
   # Import the module
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
- `Set-ECMA2ConnectorEncryptedParameter` - Sets encrypted parameter values (passwords) on the local ECMA2Host server
- `Get-ECMA2ConnectorSecret` - Decrypts encrypted parameters and secret tokens from connectors
- `Get-ECMA2ConnectorObjects` - Retrieves objects from a connector's cache using SCIM queries
- `Get-ECMA2ConnectorStatus` - Gets the status of an ECMA2 connector
- `Invoke-ECMA2ConnectorRequest` - Sends SCIM requests (GET/POST/PUT/PATCH/DELETE) to an ECMA2 connector

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

# Check status on remote computer (requires appropriate permissions)
Get-ECMA2HostStatus -ComputerName "Server01"

# Example output
ComputerName        : Server01
ServiceName         : Microsoft ECMA2Host
DisplayName         : Microsoft ECMA2Host
Status              : Running
StartType           : Auto
CanStop             : True
CanPauseAndContinue : True
DependentServices   : 0
RequiredServices    : 0
```

### Get Connector Information
```powershell
# Get all connectors (local machine)
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

# Query connectors on a remote computer
# Map a network drive to the remote computer's C$ share
New-PSDrive -Name "E" -PSProvider FileSystem -Root "\\Server01\C$" -Persist

# Access remote configuration file
Get-ECMA2Connector -ConfigurationPath 'E:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml'

# Or use UNC path directly
Get-ECMA2Connector -ConfigurationPath '\\Server01\C$\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml'
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

### Set Encrypted Parameters (Passwords)

> **Important**: This cmdlet MUST be executed locally on the ECMA2Host server or via `Invoke-Command` to that server. DPAPI encryption is machine-specific and encrypted values can only be used on the machine where they were created.

```powershell
# Set encrypted parameter on local ECMA2Host server
Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password" -Value "SecureP@ssw0rd123"

# Set multiple encrypted parameters
Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password" -Value "MainP@ssw0rd"
Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password (auxiliary)" -Value "AuxP@ssw0rd"

# Use with pipeline
Get-ECMA2Connector -Name "LDAPConnector" | 
    Set-ECMA2ConnectorEncryptedParameter -ParameterName "Password" -Value "LdapP@ssw0rd"

# Remote execution via PowerShell remoting
Invoke-Command -ComputerName "EcmaServer" -ScriptBlock {
    Import-Module ECMA2HostTools
    Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password" -Value "SecureP@ssw0rd123"
}

# Automated deployment with password from Azure Key Vault
$password = Get-AzKeyVaultSecret -VaultName "MyVault" -Name "SQL-Password" -AsPlainText
Invoke-Command -ComputerName "EcmaServer" -ScriptBlock {
    param($pwd)
    Import-Module ECMA2HostTools
    Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password" -Value $pwd
} -ArgumentList $password

# Automated deployment with password from Microsoft.PowerShell.SecretStore
$password = Get-Secret -Name "SQL-Service-Account" -AsPlainText
Invoke-Command -ComputerName "EcmaServer" -ScriptBlock {
    param($pwd, $connectorName)
    Import-Module ECMA2HostTools
    Set-ECMA2ConnectorEncryptedParameter -Name $connectorName -ParameterName "Password" -Value $pwd
    
    # Restart service to apply changes
    Restart-Service -Name "Microsoft ECMA2Host" -Force
} -ArgumentList $password, "SQLConnector"

# Extract password from one ECMA2Host server and set it on another
# Note: ECMA2HostTools module must be installed on both source and target servers
# Important: Module must be installed system-wide (AllUsers scope) on remote servers for PowerShell remoting
# Install-Module -Name ECMA2HostTools -Scope AllUsers
# Step 1: Extract password from source server
$password = Invoke-Command -ComputerName "SourceServer" -ScriptBlock {
    Import-Module ECMA2HostTools
    $secrets = Get-ECMA2ConnectorSecret -Name "SQLConnector"
    return $secrets.EncryptedParameters['Password'].Value
}

# Step 2: Set password on target server
Invoke-Command -ComputerName "TargetServer" -ScriptBlock {
    param($pwd)
    Import-Module ECMA2HostTools
    Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password" -Value $pwd
} -ArgumentList $password

# Extract SecretToken from source and set on target server(s)
# Important: The unencrypted SecretToken value must be the same on all ECMA2Host servers
# connecting to the same Entra application. However, each server encrypts it individually
# using its own machine-specific DPAPI keys, so you must set it on each server separately.
$secretToken = Invoke-Command -ComputerName "SourceServer" -ScriptBlock {
    Import-Module ECMA2HostTools
    $secrets = Get-ECMA2ConnectorSecret -Name "SQLConnector" -IncludeSecretToken
    return $secrets.SecretToken
}

# Set the same SecretToken on target server (will be encrypted for that specific machine)
Invoke-Command -ComputerName "TargetServer" -ScriptBlock {
    param($token)
    Import-Module ECMA2HostTools
    Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "SecretToken" -Value $token
} -ArgumentList $secretToken

# Set on additional servers if needed (e.g., for high availability)
# Each server will have a different encrypted value in XML, but all decrypt to the same token
Invoke-Command -ComputerName "TargetServer2" -ScriptBlock {
    param($token)
    Import-Module ECMA2HostTools
    Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "SecretToken" -Value $token
} -ArgumentList $secretToken

# View operation result
$result = Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password" -Value "P@ssw0rd"
$result | Format-List

# Example output:
# ConnectorName     : SQLConnector
# ParameterName     : Password
# ConfigurationPath : C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml
# BackupPath        : C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml.backup_20251204_131500
# Timestamp         : 12/04/2025 1:15:00 PM
# ComputerName      : ECMA2HOSTSERVER
# Success           : True

# Note: After setting encrypted parameters, restart the ECMA2Host service:
# Restart-Service -Name "Microsoft ECMA2Host" -Force
```

### Export and Import Connector Configuration

#### Export Connector Configuration
```powershell
# Export connector configuration to JSON
Export-ECMA2ConnectorConfiguration -ConnectorName "LDAPConnector" -Path "C:\Backup\LDAPConnector.json"

# Export with decrypted secrets (requires admin on ECMA2Host server)
Export-ECMA2ConnectorConfiguration -ConnectorName "LDAPConnector" -Path "C:\Backup\LDAPConnector-Full.json" -IncludeSecrets

# Force overwrite existing file
Export-ECMA2ConnectorConfiguration -ConnectorName "SQLConnector" -Path "C:\Backup\SQLConnector.json" -Force

# View export summary
$export = Export-ECMA2ConnectorConfiguration -ConnectorName "LDAPConnector" -Path "C:\Backup\LDAPConnector.json"
$export | Format-List
```

#### Import Connector Configuration

> **Important Prerequisites**: Before importing a connector configuration to a target ECMA2Host server, ensure:
> - All required connector libraries (DLLs) are installed in the ECMA folder (e.g., for Granfeldt PowerShell Management Agent: `Granfeldt.PowerShell.ManagementAgent.dll`)
> - All configuration files, scripts, and dependencies referenced by the connector are present on the target server
> - The ECMAFolderPath and script paths in the JSON match the target server's directory structure
> - The ECMA2Host service is stopped before importing to prevent conflicts
>
> **CRITICAL - Encrypted Parameters Limitation**: 
> - Encrypted parameters (passwords, SecretToken) use Windows DPAPI with LocalMachine scope, which is **machine-specific**
> - When importing to a **different server**, encrypted values from the source server **cannot be decrypted** on the target server
> - After importing to a remote server, you **must** use the ECMA2Host Configuration Wizard UI to re-enter all encrypted parameters (passwords)
> - The SecretToken will be automatically regenerated by ECMA2Host when you save the connector in the Configuration Wizard
> - Alternatively, export **without** `-IncludeSecrets`, import to the target server, then manually configure encrypted parameters in the UI

```powershell
# Import to local ECMA2Host (default configuration path)
Import-ECMA2ConnectorConfiguration -Path "C:\Backup\LDAPConnector.json"

# Import with a new connector name
Import-ECMA2ConnectorConfiguration -Path "C:\Backup\LDAPConnector.json" -ConnectorName "LDAPConnector-Test"

# Overwrite existing connector (use with caution)
Import-ECMA2ConnectorConfiguration -Path "C:\Backup\LDAPConnector.json" -Force

# Import to remote ECMA2Host using mapped network drive
# Step 1: Map network drive to remote server's C$ share
New-PSDrive -Name "E" -PSProvider FileSystem -Root "\\Server01\C$" -Persist

# Step 2: Import connector to remote Configuration.xml
Import-ECMA2ConnectorConfiguration -Path "C:\Backup\LDAPConnector.json" `
    -ConfigurationPath 'E:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml' `
    -ConnectorName "LDAPConnector"

# Or use UNC path directly (no drive mapping required)
Import-ECMA2ConnectorConfiguration -Path "C:\Backup\LDAPConnector.json" `
    -ConfigurationPath '\\Server01\C$\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml'

# View import summary
$import = Import-ECMA2ConnectorConfiguration -Path "C:\Backup\SQLConnector.json"
$import | Format-List

# Example output:
# ConnectorName       : SQLConnector
# SourceFile         : C:\Backup\SQLConnector.json
# ConfigurationPath  : C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml
# BackupPath         : C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml.backup_20251204_120137
# Action             : Created
# Timestamp          : 12/04/2025 12:01:37 PM
# ParameterCount     : 8
# IncludedSecrets    : True
```

**Complete Remote Deployment Example:**

```powershell
# Example: Deploy a Granfeldt PowerShell MA connector to a remote server

# 1. Copy connector library to remote server
Copy-Item "C:\ECMA\Granfeldt.PowerShell.ManagementAgent.dll" `
    -Destination "\\Server01\C$\Program Files\Microsoft ECMA2Host\Service\ECMA\Granfeldt.PowerShell.ManagementAgent.dll"

# 2. Copy connector scripts and configuration files
$remoteScriptPath = "\\Server01\C$\Program Files\Microsoft ECMA2Host\Service\ECMA\PSMAExtensions\MyConnector"
New-Item -Path $remoteScriptPath -ItemType Directory -Force
Copy-Item "C:\Scripts\MyConnector\*" -Destination $remoteScriptPath -Recurse -Force

# 3. Map network drive for configuration access
New-PSDrive -Name "E" -PSProvider FileSystem -Root "\\Server01\C$" -Persist

# 4. Import connector configuration to remote server
Import-ECMA2ConnectorConfiguration -Path "C:\Backup\MyConnector.json" `
    -ConfigurationPath 'E:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml' `
    -ConnectorName "MyConnector"

# 5. Verify connector was added successfully
Get-ECMA2Connector -ConfigurationPath 'E:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml' `
    -Name "MyConnector"

# 6. Configure encrypted parameters (passwords) on the remote server
#    Option A: Use the ECMA2Host Configuration Wizard UI
#    Option B: Use PowerShell remoting to set them programmatically

# Option B: Set encrypted parameters programmatically via PowerShell remoting
$password = "SecureP@ssw0rd123"  # Or retrieve from secure vault
Invoke-Command -ComputerName "Server01" -ScriptBlock {
    param($pwd, $connectorName)
    Import-Module ECMA2HostTools
    Set-ECMA2ConnectorEncryptedParameter -Name $connectorName -ParameterName "Password" -Value $pwd
} -ArgumentList $password, "MyConnector"

# 7. Restart remote ECMA2Host service to apply changes
Stop-ECMA2Host -ComputerName "Server01"
Start-Sleep -Seconds 3
Start-ECMA2Host -ComputerName "Server01"
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
> **Recommendation**: For complex filtering, retrieve all objects (default behavior) and then use PowerShell's filtering capabilities (`Where-Object`, `-like`, `-match`, `-gt`, etc.) to find specific objects. Use `-Limit` to restrict results when testing or working with large connectors.

```powershell
# Get all objects from a connector (automatically retrieves all pages)
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2Connector -Name "LDAPConnector" | Get-ECMA2ConnectorObjects -SecretToken $secret

# Combine cmdlets in pipeline to get objects with custom formatting
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2Connector -Name "LDAPConnector" | 
    Get-ECMA2ConnectorObjects -SecretToken $secret | 
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
$users = Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret

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
# CountOnly mode also returns Last-Successful timestamps for the connector
$secret = (Get-ECMA2ConnectorSecret -Name "SQLConnector" -IncludeSecretToken).SecretToken
$result = Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret -CountOnly
Write-Host "Connector has $($result.TotalCount) objects"
Write-Host "Last Import: $($result.LastSuccessfulImport)"
Write-Host "Last Export: $($result.LastSuccessfulExport)"
Write-Host "Last Cache Change: $($result.LastSuccessfulCacheChange)"

# Use CountOnly for quick validation of multiple connectors with timestamps
foreach ($connectorName in @('LDAPConnector', 'SQLConnector', 'APIConnector')) {
    $secret = (Get-ECMA2ConnectorSecret -Name $connectorName -IncludeSecretToken).SecretToken
    $result = Get-ECMA2ConnectorObjects -ConnectorName $connectorName -SecretToken $secret -CountOnly
    Write-Host "$connectorName`: $($result.TotalCount) objects, Last Import: $($result.LastSuccessfulImport)"
}

# Limit results for testing or working with large connectors
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret -Limit 50

# Get only first 10 objects for quick testing
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret -Limit 10

# Get specific page of results with StartIndex
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
    -ItemsPerPage 10 -StartIndex 11 -Limit 10

# Show detailed request/response for diagnostics
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
    -ShowDetails -ItemsPerPage 5 -Limit 5

# Access ECMA2Host-specific attributes from connector objects
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
$objects = Get-ECMA2Connector -Name "LDAPConnector" | 
    Get-ECMA2ConnectorObjects -SecretToken $secret
$objects[0].ECMA2HostAttributes  # View all connector-specific attributes
$objects[0].RawObject  # View complete SCIM response object

# Note: Port defaults to 8585. For non-default ports, use -Port parameter:
# Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret -Port 9090
```

### Send SCIM Requests to Connectors (GET/POST/PUT/PATCH/DELETE)

```powershell
# Query a specific object by ID (GET)
$secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
    -Method GET -ObjectId "12345"

# Query objects with a filter (replicate Entra SCIM queries)
$secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
Invoke-ECMA2ConnectorRequest -ConnectorName "LDAPConnector" -SecretToken $secret `
    -Method GET -FilterAttribute "urn:ietf:params:scim:schemas:extension:ECMA2Host:2.0:User:employeeId" `
    -FilterValue "12345" -ShowDetails

# Query with custom SCIM filter
$secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
    -Method GET -CustomFilter 'userName eq "jsmith"'

# Create a new user in a connector (POST)
$body = @{
    schemas = @(
        "urn:ietf:params:scim:schemas:core:2.0:User",
        "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
    )
    active = $true
    meta = @{
        resourceType = "User"
    }
    "urn:ietf:params:scim:schemas:extension:ECMA2Host:2.0:User" = @{
        id = "12345"
        displayName = "John Smith"
        emailPrimary = "john.smith@example.com"
        externalId = "EXT12345"
        userName = "jsmith"
        userType = "Employee"
    }
}

$secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret -Body $body -ShowDetails

# Update an existing user (PUT - full replacement)
$updateBody = @{
    schemas = @("urn:ietf:params:scim:schemas:core:2.0:User")
    active = $false
    "urn:ietf:params:scim:schemas:extension:ECMA2Host:2.0:User" = @{
        displayName = "John Smith (Inactive)"
    }
}

$secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
    -Method PUT -ObjectId "12345" -Body $updateBody

# Partial update (PATCH)
$patchBody = @{
    schemas = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
    Operations = @(
        @{
            op = "replace"
            path = "active"
            value = $false
        }
    )
}

$secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
    -Method PATCH -ObjectId "12345" -Body $patchBody

# Delete a user
$secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
    -Method DELETE -ObjectId "12345"

# Pipeline from Get-ECMA2Connector
$secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
Get-ECMA2Connector -Name "APIConnector" |
    Invoke-ECMA2ConnectorRequest -SecretToken $secret -Method DELETE -ObjectId "12345"

# Preview changes without applying them (WhatIf)
$secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
    -Method DELETE -ObjectId "12345" -WhatIf
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
## Requirements

- PowerShell 5.1 or later (PowerShell 7+ supported with automatic fallback for decryption)
- ECMA2Host installed on the target system
- **Administrator privileges required** for service management operations (Start/Stop/Resume)
- Appropriate permissions to manage services and connectors
- **Secret decryption must run on the same machine** where ECMA2Host is installed (uses DPAPI LocalMachine scope)

### Remote Management Requirements

- **Service Status Queries**: Remote service queries require appropriate WMI/CIM permissions on the target computer
- **Configuration File Access**: Reading remote configuration files requires:
  - Network access to the remote computer's admin shares (e.g., `\\Server01\C$`)
  - File system permissions to read the Configuration.xml file
  - Either map a network drive or use UNC paths with the `-ConfigurationPath` parameter
- **Secret Decryption**: Must be performed locally on the ECMA2Host server (cannot decrypt secrets from remote configuration files)
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
- ✅ `Set-ECMA2ConnectorEncryptedParameter` - Fully implemented, sets encrypted parameters with DPAPI encryption
- ✅ `Get-ECMA2ConnectorSecret` - Fully implemented, decrypts passwords and tokens (PS7+ and PS5.1 compatible)
- ✅ `Get-ECMA2ConnectorObjects` - Fully implemented, queries connector cache using SCIM protocol with timestamp tracking
- ✅ `Get-ECMA2ConnectorStatus` - Fully implemented, shows connector operational status
- ✅ `Get-ECMA2ConnectorRunHistory` - Fully implemented, retrieves run history from ECMA2Host event log
- ✅ `Invoke-ECMA2ConnectorRequest` - Fully implemented, sends SCIM requests (GET/POST/PUT/PATCH/DELETE) to connectors
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
