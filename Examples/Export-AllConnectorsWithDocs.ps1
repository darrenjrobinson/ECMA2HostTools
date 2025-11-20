<#
.SYNOPSIS
    Exports all ECMA2 connector configurations and generates documentation for each.

.DESCRIPTION
    This script retrieves all ECMA2 connectors, exports their configuration to JSON files,
    and generates markdown documentation for each connector. Useful for backup, documentation,
    and configuration management purposes.

.PARAMETER OutputPath
    The directory where connector exports and documentation will be saved.
    Defaults to C:\ECMA2Host\Exports\[timestamp]

.PARAMETER IncludeSecrets
    Include decrypted secrets in the exported JSON files.
    Requires the script to run on the ECMA2Host server with appropriate permissions.

.PARAMETER GenerateDocumentation
    Generate markdown documentation for each connector (default: $true).

.PARAMETER SkipExport
    Skip the JSON export and only generate documentation.

.EXAMPLE
    .\Export-AllConnectorsWithDocs.ps1
    
    Exports all connectors and generates documentation in default location.

.EXAMPLE
    .\Export-AllConnectorsWithDocs.ps1 -OutputPath "C:\Backup\Connectors" -IncludeSecrets
    
    Exports all connectors with decrypted secrets to specified directory.

.EXAMPLE
    .\Export-AllConnectorsWithDocs.ps1 -OutputPath "C:\Docs" -SkipExport
    
    Only generates documentation for all connectors, skips JSON export.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath,
    
    [Parameter()]
    [switch]$IncludeSecrets,
    
    [Parameter()]
    [switch]$GenerateDocumentation = $true,
    
    [Parameter()]
    [switch]$SkipExport
)

# Import the module (use relative path if not in module directory)
$modulePath = Join-Path $PSScriptRoot "..\ECMA2HostTools.psd1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force -ErrorAction Stop
} else {
    Import-Module ECMA2HostTools -ErrorAction Stop
}

# Set default output path if not specified
if ([string]::IsNullOrEmpty($OutputPath)) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputPath = "C:\ECMA2Host\Exports\$timestamp"
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
}

# Get all connectors
Write-Host "`nRetrieving all ECMA2 connectors..." -ForegroundColor Cyan
try {
    $connectors = Get-ECMA2Connector
    
    if (-not $connectors) {
        Write-Warning "No connectors found."
        exit 0
    }
    
    Write-Host "Found $($connectors.Count) connector(s)`n" -ForegroundColor Green
}
catch {
    Write-Error "Failed to retrieve connectors: $_"
    exit 1
}

# Initialize summary
$summary = @{
    TotalConnectors = $connectors.Count
    Exported = 0
    ExportFailed = 0
    Documented = 0
    DocumentFailed = 0
    Errors = @()
}

# Process each connector
foreach ($connector in $connectors) {
    $connectorName = $connector.Name
    Write-Host "Processing connector: $connectorName" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Gray
    
    # Export connector configuration
    if (-not $SkipExport) {
        $exportPath = Join-Path $OutputPath "$connectorName.json"
        
        try {
            Write-Host "  Exporting configuration to JSON..." -ForegroundColor White
            
            $exportParams = @{
                ConnectorName = $connectorName
                Path = $exportPath
                Force = $true
            }
            
            if ($IncludeSecrets) {
                $exportParams['IncludeSecrets'] = $true
                Write-Host "    Including decrypted secrets" -ForegroundColor Gray
            }
            
            $result = Export-ECMA2ConnectorConfiguration @exportParams
            
            if ($result) {
                Write-Host "    ✓ Exported successfully: $exportPath" -ForegroundColor Green
                Write-Host "      Size: $([math]::Round((Get-Item $exportPath).Length / 1KB, 2)) KB" -ForegroundColor Gray
                $summary.Exported++
            }
        }
        catch {
            Write-Host "    ✗ Export failed: $_" -ForegroundColor Red
            $summary.ExportFailed++
            $summary.Errors += @{
                Connector = $connectorName
                Operation = "Export"
                Error = $_.Exception.Message
            }
        }
    }
    
    # Generate documentation
    if ($GenerateDocumentation) {
        $docPath = Join-Path $OutputPath "$connectorName.md"
        
        try {
            Write-Host "  Generating documentation..." -ForegroundColor White
            
            $result = New-ECMA2ConnectorDocumentation -ConnectorName $connectorName -Path $docPath
            
            if ($result) {
                Write-Host "    ✓ Documentation generated: $docPath" -ForegroundColor Green
                Write-Host "      Size: $([math]::Round((Get-Item $docPath).Length / 1KB, 2)) KB" -ForegroundColor Gray
                $summary.Documented++
            }
        }
        catch {
            Write-Host "    ✗ Documentation generation failed: $_" -ForegroundColor Red
            $summary.DocumentFailed++
            $summary.Errors += @{
                Connector = $connectorName
                Operation = "Documentation"
                Error = $_.Exception.Message
            }
        }
    }
    
    Write-Host ""
}

# Display summary
Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan

Write-Host "`nOutput Directory: $OutputPath" -ForegroundColor Yellow

if (-not $SkipExport) {
    Write-Host "`nConfiguration Exports:" -ForegroundColor White
    Write-Host "  Total Connectors:  $($summary.TotalConnectors)" -ForegroundColor Gray
    Write-Host "  Exported:          $($summary.Exported)" -ForegroundColor Green
    if ($summary.ExportFailed -gt 0) {
        Write-Host "  Failed:            $($summary.ExportFailed)" -ForegroundColor Red
    }
}

if ($GenerateDocumentation) {
    Write-Host "`nDocumentation:" -ForegroundColor White
    Write-Host "  Total Connectors:  $($summary.TotalConnectors)" -ForegroundColor Gray
    Write-Host "  Documented:        $($summary.Documented)" -ForegroundColor Green
    if ($summary.DocumentFailed -gt 0) {
        Write-Host "  Failed:            $($summary.DocumentFailed)" -ForegroundColor Red
    }
}

# Show errors if any
if ($summary.Errors.Count -gt 0) {
    Write-Host "`nErrors:" -ForegroundColor Red
    foreach ($error in $summary.Errors) {
        Write-Host "  Connector: $($error.Connector)" -ForegroundColor Yellow
        Write-Host "  Operation: $($error.Operation)" -ForegroundColor Gray
        Write-Host "  Error:     $($error.Error)" -ForegroundColor Red
        Write-Host ""
    }
}

# Generate index file
$indexPath = Join-Path $OutputPath "README.md"
Write-Host "`nGenerating index file: $indexPath" -ForegroundColor Cyan

$indexContent = @"
# ECMA2Host Connector Export

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Summary

- **Total Connectors**: $($summary.TotalConnectors)
- **Successfully Exported**: $($summary.Exported)
- **Successfully Documented**: $($summary.Documented)
"@

if ($summary.ExportFailed -gt 0 -or $summary.DocumentFailed -gt 0) {
    $indexContent += "`n- **Failed Operations**: $($summary.ExportFailed + $summary.DocumentFailed)"
}

$indexContent += @"


## Connectors

| Connector Name | JSON Export | Documentation |
|----------------|-------------|---------------|
"@

foreach ($connector in $connectors) {
    $connectorName = $connector.Name
    $jsonExists = Test-Path (Join-Path $OutputPath "$connectorName.json")
    $mdExists = Test-Path (Join-Path $OutputPath "$connectorName.md")
    
    $jsonLink = if ($jsonExists) { "✓ [$connectorName.json](./$connectorName.json)" } else { "✗" }
    $mdLink = if ($mdExists) { "✓ [$connectorName.md](./$connectorName.md)" } else { "✗" }
    
    $indexContent += "`n| $connectorName | $jsonLink | $mdLink |"
}

if ($IncludeSecrets) {
    $indexContent += @"


## ⚠️ Security Notice

**IMPORTANT**: The exported JSON files contain decrypted secrets and sensitive credentials.

- Store these files securely
- Do not commit to source control
- Restrict access to authorized personnel only
- Delete when no longer needed
"@
}

$indexContent | Out-File -FilePath $indexPath -Encoding UTF8 -Force
Write-Host "Index file created successfully" -ForegroundColor Green

# Open output directory
Write-Host "`nOpening output directory..." -ForegroundColor Cyan
Invoke-Item $OutputPath

Write-Host "`nExport complete!" -ForegroundColor Green
