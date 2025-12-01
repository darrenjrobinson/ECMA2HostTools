<#
.SYNOPSIS
    Validates connector caches by querying object counts.

.DESCRIPTION
    This script enumerates all ECMA2Host connectors, retrieves their secret tokens,
    and queries each connector to determine how many resources are present.
    
    By default, uses -CountOnly for efficient count retrieval (single HTTP request).
    Use -GetAllObjects to retrieve all objects and show last page resources.

.PARAMETER ConfigurationPath
    Path to the ECMA2Host Configuration.xml file.

.PARAMETER GetAllObjects
    Retrieve all objects from each connector (slower but shows last page resources).

.PARAMETER SkipCertificateCheck
    Skip SSL certificate validation.

.EXAMPLE
    .\Validate-ConnectorCaches.ps1
    
    Quickly validates all connector caches using -CountOnly (most efficient).

.EXAMPLE
    .\Validate-ConnectorCaches.ps1 -GetAllObjects
    
    Retrieves all objects and shows last page resources for each connector (slower).

.EXAMPLE
    .\Validate-ConnectorCaches.ps1 | Export-Csv -Path ConnectorCacheReport.csv -NoTypeInformation
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigurationPath = 'C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml',
    
    [Parameter()]
    [switch]$GetAllObjects,
    
    [Parameter()]
    [switch]$SkipCertificateCheck
)

# Import the module if not already loaded
if (-not (Get-Module -Name ECMA2HostTools)) {
    Import-Module ECMA2HostTools -ErrorAction Stop
}

Write-Host "Enumerating ECMA2Host connectors..." -ForegroundColor Cyan

# Get all connectors
try {
    $connectors = Get-ECMA2Connector -ConfigurationPath $ConfigurationPath
    
    if (-not $connectors) {
        Write-Warning "No connectors found in configuration."
        return
    }
    
    Write-Host "Found $($connectors.Count) connector(s)`n" -ForegroundColor Green
}
catch {
    Write-Error "Failed to retrieve connectors: $_"
    return
}

# Initialize results array
$results = @()

# Process each connector
foreach ($connector in $connectors) {
    Write-Host "Processing connector: $($connector.Name)" -ForegroundColor Yellow
    
    try {
        # Get the secret token for this connector
        Write-Verbose "Retrieving secret token for $($connector.Name)..."
        $secretInfo = Get-ECMA2ConnectorSecret -Name $connector.Name -ConfigurationPath $ConfigurationPath -IncludeSecretToken
        
        if (-not $secretInfo -or [string]::IsNullOrEmpty($secretInfo.SecretToken)) {
            Write-Warning "  ✗ Could not retrieve secret token for $($connector.Name) - skipping"
            
            $results += [PSCustomObject]@{
                ConnectorName = $connector.Name
                ResourceCount = 0
                Status = "No Secret Token"
                LastSuccessfulImport = $null
                LastSuccessfulExport = $null
                LastSuccessfulCacheChange = $null
                LastPageResources = @{}
                Error = "Could not retrieve secret token"
            }
            continue
        }
        
        # Query connector - CountOnly mode is most efficient, full mode gets all objects
        Write-Verbose "Querying objects from $($connector.Name)..."
        
        if ($GetAllObjects) {
            # Retrieve all objects
            $queryParams = @{
                ConnectorName = $connector.Name
                SecretToken = $secretInfo.SecretToken
                ErrorAction = 'Stop'
            }
            
            if ($SkipCertificateCheck) {
                $queryParams['SkipCertificateCheck'] = $true
            }
            
            $objects = @(Get-ECMA2ConnectorObjects @queryParams)
            $objectCount = $objects.Count
            $lastImport = $null
            $lastExport = $null
            $lastCacheChange = $null
        } else {
            # Use CountOnly for efficient single-request count
            $queryParams = @{
                ConnectorName = $connector.Name
                SecretToken = $secretInfo.SecretToken
                CountOnly = $true
                ErrorAction = 'Stop'
            }
            
            if ($SkipCertificateCheck) {
                $queryParams['SkipCertificateCheck'] = $true
            }
            
            $countResult = Get-ECMA2ConnectorObjects @queryParams
            $objectCount = $countResult.TotalCount
            $lastImport = $countResult.LastSuccessfulImport
            $lastExport = $countResult.LastSuccessfulExport
            $lastCacheChange = $countResult.LastSuccessfulCacheChange
            $objects = @()  # No objects retrieved in CountOnly mode
        }
        
        # Build last page resources only if GetAllObjects is specified
        $lastPageHash = @{}
        if ($GetAllObjects -and $objectCount -gt 0 -and $objects.Count -gt 0) {
            # Get the last page of resources (last 10 objects)
            $lastPageObjects = $objects | Select-Object -Last 10
            
            foreach ($obj in $lastPageObjects) {
                $displayValue = if ($obj.DisplayName) { 
                    $obj.DisplayName 
                } elseif ($obj.UserName) { 
                    $obj.UserName 
                } elseif ($obj.ExternalId) {
                    $obj.ExternalId
                } else { 
                    "N/A" 
                }
                
                $lastPageHash[$obj.Id] = $displayValue
            }
        }
        
        $mode = if ($GetAllObjects) { "" } else { " [CountOnly mode]" }
        Write-Host "  ✓ Found $objectCount object(s)$mode" -ForegroundColor Green
        
        $results += [PSCustomObject]@{
            ConnectorName = $connector.Name
            ResourceCount = $objectCount
            Status = "Success"
            LastSuccessfulImport = $lastImport
            LastSuccessfulExport = $lastExport
            LastSuccessfulCacheChange = $lastCacheChange
            LastPageResources = $lastPageHash
            Error = $null
        }
    }
    catch {
        Write-Warning "  ✗ Error querying $($connector.Name): $_"
        
        $results += [PSCustomObject]@{
            ConnectorName = $connector.Name
            ResourceCount = 0
            Status = "Error"
            LastSuccessfulImport = $null
            LastSuccessfulExport = $null
            LastSuccessfulCacheChange = $null
            LastPageResources = @{}
            Error = $_.Exception.Message
        }
    }
    
    Write-Host ""
}

# Output summary table
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CONNECTOR CACHE VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$results | Format-Table -Property ConnectorName, ResourceCount, Status, LastSuccessfulImport, LastSuccessfulExport, LastSuccessfulCacheChange -AutoSize

# Output detailed results with last page resources
Write-Host "`nDetailed Results:" -ForegroundColor Cyan
Write-Host "----------------------------------------`n" -ForegroundColor Cyan

foreach ($result in $results) {
    Write-Host "Connector: $($result.ConnectorName)" -ForegroundColor Yellow
    Write-Host "  Resource Count: $($result.ResourceCount)" -ForegroundColor Gray
    Write-Host "  Status: $($result.Status)" -ForegroundColor Gray
    
    if ($result.LastSuccessfulImport) {
        Write-Host "  Last Successful Import: $($result.LastSuccessfulImport)" -ForegroundColor Gray
    }
    if ($result.LastSuccessfulExport) {
        Write-Host "  Last Successful Export: $($result.LastSuccessfulExport)" -ForegroundColor Gray
    }
    if ($result.LastSuccessfulCacheChange) {
        Write-Host "  Last Successful Cache Change: $($result.LastSuccessfulCacheChange)" -ForegroundColor Gray
    }
    
    if ($result.LastPageResources.Count -gt 0) {
        Write-Host "  Last Page Resources ($($result.LastPageResources.Count) items):" -ForegroundColor Gray
        foreach ($key in $result.LastPageResources.Keys) {
            Write-Host "    $key : $($result.LastPageResources[$key])" -ForegroundColor DarkGray
        }
    } elseif ($result.ResourceCount -eq 0 -and $result.Status -eq "Success") {
        Write-Host "  Last Page Resources: (No objects found)" -ForegroundColor DarkGray
    }
    
    if ($result.Error) {
        Write-Host "  Error: $($result.Error)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Return results for pipeline/export
return $results
