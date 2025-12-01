<#
.SYNOPSIS
    Retrieves connector objects modified within a specified time range.

.DESCRIPTION
    Queries ECMA2Host connector objects and filters them based on their meta.lastModified timestamp.
    Returns objects that have been modified within the last X hours/days/minutes.

.PARAMETER ConnectorName
    Name of the ECMA2Host connector to query.

.PARAMETER ConfigurationPath
    Path to the ECMA2Host Configuration.xml file.

.PARAMETER Hours
    Filter objects modified within the last X hours.

.PARAMETER Days
    Filter objects modified within the last X days.

.PARAMETER Minutes
    Filter objects modified within the last X minutes.

.PARAMETER After
    Filter objects modified after a specific DateTime.

.PARAMETER SkipCertificateCheck
    Skip SSL certificate validation.

.PARAMETER ShowProgress
    Display progress information during object retrieval.

.EXAMPLE
    .\Get-RecentlyModifiedObjects.ps1 -ConnectorName "LDAPConnector" -Hours 24
    
    Retrieves all objects from LDAPConnector modified in the last 24 hours.

.EXAMPLE
    .\Get-RecentlyModifiedObjects.ps1 -ConnectorName "SQLConnector" -Days 7
    
    Retrieves all objects from SQLConnector modified in the last 7 days.

.EXAMPLE
    .\Get-RecentlyModifiedObjects.ps1 -ConnectorName "LDAPConnector" -Minutes 30
    
    Retrieves all objects from LDAPConnector modified in the last 30 minutes.

.EXAMPLE
    .\Get-RecentlyModifiedObjects.ps1 -ConnectorName "SQLConnector" -After "2025-11-01T00:00:00Z"
    
    Retrieves all objects modified after November 1, 2025.

.EXAMPLE
    .\Get-RecentlyModifiedObjects.ps1 -ConnectorName "LDAPConnector" -Hours 24 -ShowProgress
    
    Retrieves objects with progress information displayed.

.EXAMPLE
    $recentUsers = .\Get-RecentlyModifiedObjects.ps1 -ConnectorName "LDAPConnector" -Hours 24
    $recentUsers | Select-Object Id, DisplayName, @{N='LastModified';E={$_.ECMA2HostAttributes.meta.lastModified}}
#>

[CmdletBinding(DefaultParameterSetName = 'Hours')]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConnectorName,
    
    [Parameter()]
    [string]$ConfigurationPath = 'C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml',
    
    [Parameter(ParameterSetName = 'Hours')]
    [int]$Hours,
    
    [Parameter(ParameterSetName = 'Days')]
    [int]$Days,
    
    [Parameter(ParameterSetName = 'Minutes')]
    [int]$Minutes,
    
    [Parameter(ParameterSetName = 'DateTime')]
    [DateTime]$After,
    
    [Parameter()]
    [switch]$SkipCertificateCheck,
    
    [Parameter()]
    [switch]$ShowProgress
)

# Import the module if not already loaded
if (-not (Get-Module -Name ECMA2HostTools)) {
    Import-Module ECMA2HostTools -ErrorAction Stop
}

# Calculate the threshold DateTime based on parameters
if ($PSCmdlet.ParameterSetName -eq 'Hours') {
    $threshold = (Get-Date).AddHours(-$Hours)
    $timeRangeDescription = "last $Hours hour$(if ($Hours -ne 1) {'s'})"
}
elseif ($PSCmdlet.ParameterSetName -eq 'Days') {
    $threshold = (Get-Date).AddDays(-$Days)
    $timeRangeDescription = "last $Days day$(if ($Days -ne 1) {'s'})"
}
elseif ($PSCmdlet.ParameterSetName -eq 'Minutes') {
    $threshold = (Get-Date).AddMinutes(-$Minutes)
    $timeRangeDescription = "last $Minutes minute$(if ($Minutes -ne 1) {'s'})"
}
else {
    $threshold = $After
    $timeRangeDescription = "after $($After.ToString('yyyy-MM-dd HH:mm:ss'))"
}

Write-Host "Querying connector: $ConnectorName" -ForegroundColor Cyan
Write-Host "Filter: Objects modified $timeRangeDescription" -ForegroundColor Cyan
Write-Host "Threshold DateTime: $($threshold.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))`n" -ForegroundColor Gray

# Get the connector secret token
try {
    Write-Verbose "Retrieving secret token for $ConnectorName..."
    $secretInfo = Get-ECMA2ConnectorSecret -Name $ConnectorName -ConfigurationPath $ConfigurationPath -IncludeSecretToken
    
    if (-not $secretInfo -or [string]::IsNullOrEmpty($secretInfo.SecretToken)) {
        Write-Error "Could not retrieve secret token for connector: $ConnectorName"
        return
    }
}
catch {
    Write-Error "Failed to retrieve secret token: $_"
    return
}

# Retrieve all objects from the connector
try {
    if ($ShowProgress) {
        Write-Host "Retrieving all objects from connector..." -ForegroundColor Yellow
    }
    
    $queryParams = @{
        ConnectorName = $ConnectorName
        SecretToken = $secretInfo.SecretToken
        ErrorAction = 'Stop'
    }
    
    if ($SkipCertificateCheck) {
        $queryParams['SkipCertificateCheck'] = $true
    }
    
    $allObjects = @(Get-ECMA2ConnectorObjects @queryParams)
    
    if ($ShowProgress) {
        Write-Host "Retrieved $($allObjects.Count) total objects`n" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to retrieve objects from connector: $_"
    return
}

# Filter objects by lastModified timestamp
$filteredObjects = @()
$processedCount = 0

if ($ShowProgress) {
    Write-Host "Filtering objects by modification date..." -ForegroundColor Yellow
}

foreach ($obj in $allObjects) {
    $processedCount++
    
    if ($ShowProgress -and $processedCount % 100 -eq 0) {
        Write-Progress -Activity "Filtering Objects" -Status "Processed $processedCount of $($allObjects.Count)" -PercentComplete (($processedCount / $allObjects.Count) * 100)
    }
    
    # Check if the object has meta.lastModified
    if ($obj.ECMA2HostAttributes.meta -and $obj.ECMA2HostAttributes.meta.lastModified) {
        try {
            # Parse the lastModified timestamp (removing quotes if present)
            $lastModifiedStr = $obj.ECMA2HostAttributes.meta.lastModified -replace '"', ''
            $lastModified = [DateTime]::Parse($lastModifiedStr)
            
            # Compare with threshold
            if ($lastModified -gt $threshold) {
                $filteredObjects += $obj
            }
        }
        catch {
            Write-Verbose "Failed to parse lastModified for object ID $($obj.Id): $_"
        }
    }
}

if ($ShowProgress) {
    Write-Progress -Activity "Filtering Objects" -Completed
}

# Display results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RECENTLY MODIFIED OBJECTS REPORT" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Connector: $ConnectorName" -ForegroundColor Yellow
Write-Host "Total Objects Retrieved: $($allObjects.Count)" -ForegroundColor Gray
Write-Host "Modified $timeRangeDescription`: $($filteredObjects.Count)" -ForegroundColor Green
Write-Host ""

if ($filteredObjects.Count -gt 0) {
    Write-Host "Recently Modified Objects:" -ForegroundColor Cyan
    Write-Host "----------------------------------------`n" -ForegroundColor Cyan
    
    # Create summary output
    $summary = $filteredObjects | ForEach-Object {
        $lastModifiedStr = $_.ECMA2HostAttributes.meta.lastModified -replace '"', ''
        
        [PSCustomObject]@{
            Id = $_.Id
            DisplayName = if ($_.ECMA2HostAttributes.displayName) { $_.ECMA2HostAttributes.displayName } else { 'N/A' }
            UserName = if ($_.ECMA2HostAttributes.userName) { $_.ECMA2HostAttributes.userName } else { 'N/A' }
            ExternalId = if ($_.ECMA2HostAttributes.externalId) { $_.ECMA2HostAttributes.externalId } else { 'N/A' }
            LastModified = $lastModifiedStr
            Active = if ($_.ECMA2HostAttributes.active) { $_.ECMA2HostAttributes.active } else { 'N/A' }
        }
    }
    
    $summary | Sort-Object LastModified -Descending | Format-Table -AutoSize
    
    Write-Host "`nMost Recently Modified:" -ForegroundColor Cyan
    $mostRecent = $summary | Sort-Object LastModified -Descending | Select-Object -First 5
    $mostRecent | Format-List
}
else {
    Write-Host "No objects found modified $timeRangeDescription" -ForegroundColor Yellow
}

# Return the filtered objects for pipeline use
return $filteredObjects
