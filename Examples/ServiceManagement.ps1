<#
.SYNOPSIS
    Example script demonstrating ECMA2Host service management.

.DESCRIPTION
    This script shows how to use the ECMA2HostTools module to manage
    the ECMA2Host service including starting, stopping, and monitoring.
#>

# Import the module
Import-Module ECMA2HostTools -Force

# Example 1: Check service status
Write-Host "Checking ECMA2Host service status..." -ForegroundColor Cyan
$status = Get-ECMA2HostStatus
$status | Format-List

# Example 2: Start the service if it's stopped
if ($status.Status -ne 'Running') {
    Write-Host "Starting ECMA2Host service..." -ForegroundColor Cyan
    Start-ECMA2Host -Verbose
    
    # Verify it started
    $status = Get-ECMA2HostStatus
    Write-Host "Service Status: $($status.Status)" -ForegroundColor Green
}
else {
    Write-Host "Service is already running" -ForegroundColor Green
}

# Example 3: Get status on a remote computer (uncomment to use)
# Get-ECMA2HostStatus -ComputerName "RemoteServer" -Credential (Get-Credential)

# Example 4: Stop the service gracefully (uncomment to use)
# Write-Host "Stopping ECMA2Host service..." -ForegroundColor Yellow
# Stop-ECMA2Host -Verbose

# Example 5: Force stop the service (uncomment to use)
# Stop-ECMA2Host -Force -Verbose
