<#
.SYNOPSIS
    Example script demonstrating ECMA2 connector operations.

.DESCRIPTION
    This script shows how to use the ECMA2HostTools module to work
    with connectors including listing, starting, stopping, and checking status.
#>

# Import the module
Import-Module ECMA2HostTools -Force

# Example 1: Get all connectors
Write-Host "Getting all ECMA2 connectors..." -ForegroundColor Cyan
$connectors = Get-ECMA2Connector
$connectors | Format-Table

# Example 2: Get specific connector
Write-Host "Getting specific connector..." -ForegroundColor Cyan
$connector = Get-ECMA2Connector -Name "SQLConnector"
$connector | Format-List

# Example 3: Get connector status
Write-Host "Checking connector status..." -ForegroundColor Cyan
$status = Get-ECMA2ConnectorStatus -Name "SQLConnector"
$status | Format-List

# Example 4: Get all connectors matching a pattern
Write-Host "Getting connectors matching pattern..." -ForegroundColor Cyan
$adConnectors = Get-ECMA2Connector -Name "AD*"
$adConnectors | Format-Table

# Example 7: Check status of all connectors
Write-Host "Checking status of all connectors..." -ForegroundColor Cyan
$allStatus = Get-ECMA2ConnectorStatus
$allStatus | Format-Table
