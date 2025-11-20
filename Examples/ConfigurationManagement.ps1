<#
.SYNOPSIS
    Example script demonstrating configuration management.

.DESCRIPTION
    This script shows how to use the ECMA2HostTools module to export
    and import connector configurations for backup and migration.
#>

# Import the module
Import-Module ECMA2HostTools -Force

# Define paths
$backupDir = "C:\ECMA2Backup"
$configFile = Join-Path $backupDir "ADConnector_$(Get-Date -Format 'yyyyMMdd_HHmmss').xml"

# Create backup directory if it doesn't exist
if (-not (Test-Path $backupDir)) {
    New-Item -Path $backupDir -ItemType Directory | Out-Null
    Write-Host "Created backup directory: $backupDir" -ForegroundColor Green
}

# Example 1: Export a connector configuration
Write-Host "`nExporting connector configuration..." -ForegroundColor Cyan
Export-ECMA2ConnectorConfiguration -ConnectorName "ADConnector" -Path $configFile -Verbose

if (Test-Path $configFile) {
    Write-Host "Configuration exported successfully to: $configFile" -ForegroundColor Green
}

# Example 2: Export all connectors (uncomment to use)
# Write-Host "`nExporting all connector configurations..." -ForegroundColor Cyan
# $connectors = Get-ECMA2Connector
# foreach ($connector in $connectors) {
#     $file = Join-Path $backupDir "$($connector.Name)_$(Get-Date -Format 'yyyyMMdd_HHmmss').xml"
#     Export-ECMA2ConnectorConfiguration -ConnectorName $connector.Name -Path $file -Verbose
# }

# Example 3: Import a connector configuration (uncomment to use)
# Write-Host "`nImporting connector configuration..." -ForegroundColor Cyan
# Import-ECMA2ConnectorConfiguration -Path $configFile -Verbose

# Example 4: Import with a new name (uncomment to use)
# Write-Host "`nImporting connector with new name..." -ForegroundColor Cyan
# Import-ECMA2ConnectorConfiguration -Path $configFile -ConnectorName "ADConnector_New" -Verbose

# Example 5: Import and overwrite existing (uncomment to use)
# Write-Host "`nImporting and overwriting existing connector..." -ForegroundColor Yellow
# Import-ECMA2ConnectorConfiguration -Path $configFile -Force -Verbose

# List backup files
Write-Host "`nBackup files in ${backupDir} :" -ForegroundColor Cyan
Get-ChildItem -Path $backupDir -Filter "*.xml" | 
    Select-Object Name, Length, LastWriteTime | 
    Format-Table -AutoSize
