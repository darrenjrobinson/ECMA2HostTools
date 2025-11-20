# Build Script for ECMA2HostTools Module

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Build', 'Test', 'Analyze', 'Clean', 'All')]
    [string]$Task = 'All'
)

$ErrorActionPreference = 'Stop'
$ModuleName = 'ECMA2HostTools'
$ModulePath = $PSScriptRoot

Write-Host "Starting build process for $ModuleName..." -ForegroundColor Cyan

function Invoke-ModuleClean {
    Write-Host "`nCleaning module..." -ForegroundColor Yellow
    
    # Remove any build artifacts
    $buildArtifacts = @(
        (Join-Path $ModulePath 'Build'),
        (Join-Path $ModulePath '*.zip')
    )
    
    foreach ($artifact in $buildArtifacts) {
        if (Test-Path $artifact) {
            Remove-Item $artifact -Recurse -Force
            Write-Host "Removed: $artifact" -ForegroundColor Gray
        }
    }
}

function Invoke-ModuleBuild {
    Write-Host "`nBuilding module..." -ForegroundColor Cyan
    
    # Verify required files exist
    $requiredFiles = @(
        "$ModuleName.psd1",
        "$ModuleName.psm1"
    )
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $ModulePath $file
        if (-not (Test-Path $filePath)) {
            throw "Required file not found: $file"
        }
    }
    
    # Test module manifest
    Write-Host "Testing module manifest..." -ForegroundColor Gray
    $manifest = Test-ModuleManifest -Path (Join-Path $ModulePath "$ModuleName.psd1") -ErrorAction Stop
    Write-Host "Module version: $($manifest.Version)" -ForegroundColor Green
    Write-Host "Exported functions: $($manifest.ExportedFunctions.Count)" -ForegroundColor Green
    
    Write-Host "Build completed successfully!" -ForegroundColor Green
}

function Invoke-ModuleTest {
    Write-Host "`nRunning tests..." -ForegroundColor Cyan
    
    # Check if Pester is installed
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Write-Warning "Pester is not installed. Install it with: Install-Module Pester -RequiredVersion 3.4.0 -Force"
        return
    }
    
    $testsPath = Join-Path $ModulePath 'Tests'
    if (Test-Path $testsPath) {
        Import-Module Pester -MinimumVersion 3.0 -MaximumVersion 3.9.9 -ErrorAction Stop
        $result = Invoke-Pester -Path $testsPath -PassThru
        
        if ($result.FailedCount -gt 0) {
            throw "Tests failed: $($result.FailedCount) failed out of $($result.TotalCount)"
        }
        Write-Host "All tests passed!" -ForegroundColor Green
    }
    else {
        Write-Warning "Tests directory not found at: $testsPath"
    }
}

function Invoke-ModuleAnalyze {
    Write-Host "`nAnalyzing module with PSScriptAnalyzer..." -ForegroundColor Cyan
    
    # Check if PSScriptAnalyzer is installed
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Warning "PSScriptAnalyzer is not installed. Install it with: Install-Module PSScriptAnalyzer -Force"
        return
    }
    
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    
    $results = Invoke-ScriptAnalyzer -Path $ModulePath -Recurse -Severity Warning, Error
    
    if ($results) {
        Write-Host "Found $($results.Count) issues:" -ForegroundColor Yellow
        $results | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize
    }
    else {
        Write-Host "No issues found!" -ForegroundColor Green
    }
}

# Execute tasks
try {
    switch ($Task) {
        'Clean' { Invoke-ModuleClean }
        'Build' { Invoke-ModuleBuild }
        'Test' { Invoke-ModuleTest }
        'Analyze' { Invoke-ModuleAnalyze }
        'All' {
            Invoke-ModuleClean
            Invoke-ModuleBuild
            Invoke-ModuleAnalyze
            Invoke-ModuleTest
        }
    }
    
    Write-Host "`nBuild process completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "`nBuild process failed: $_" -ForegroundColor Red
    exit 1
}
