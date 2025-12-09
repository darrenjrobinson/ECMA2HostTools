<#
.SYNOPSIS
    Signs the ECMA2HostTools module and all PowerShell script files.

.DESCRIPTION
    This script signs the module manifest, module file, and all .ps1 files
    in the module directory structure using a code signing certificate.
    
    Uses the certificate from the Current User's Personal store with the
    specified thumbprint and timestamps using DigiCert's timestamp server.

.PARAMETER CertificateThumbprint
    The thumbprint of the code signing certificate. 
    Default: 03ea1833246380e76e393d76a53f42bbaf1eba87

.PARAMETER TimeStampServer
    The timestamp server URL. Default: http://timestamp.digicert.com

.PARAMETER WhatIf
    Shows what would be signed without actually signing.

.EXAMPLE
    .\Sign-Module.ps1
    Signs all module files using the default certificate.

.EXAMPLE
    .\Sign-Module.ps1 -WhatIf
    Shows what files would be signed without actually signing them.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$CertificateThumbprint = "03ea1833246380e76e393d76a53f42bbaf1eba87",
    
    [Parameter()]
    [string]$TimeStampServer = "http://timestamp.digicert.com"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== ECMA2HostTools Module Signing Script ===" -ForegroundColor Cyan
Write-Host ""

# Get the module root directory (script location)
$ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Verbose "Module Root: $ModuleRoot"
Write-Verbose "Certificate Thumbprint: $CertificateThumbprint"
Write-Verbose "Timestamp Server: $TimeStampServer"

# Retrieve the certificate
Write-Host "Retrieving code signing certificate..." -ForegroundColor Yellow
try {
    $cert = Get-ChildItem -Path Cert:\CurrentUser\My\$CertificateThumbprint -ErrorAction Stop
    
    Write-Host "✓ Certificate found: $($cert.Subject)" -ForegroundColor Green
    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
    Write-Host "  Valid From: $($cert.NotBefore)" -ForegroundColor Gray
    Write-Host "  Valid To: $($cert.NotAfter)" -ForegroundColor Gray
    
    # Check if certificate is valid for code signing
    if ($cert.NotAfter -lt (Get-Date)) {
        Write-Error "Certificate has expired on $($cert.NotAfter)"
        exit 1
    }
    
    if ($cert.NotBefore -gt (Get-Date)) {
        Write-Error "Certificate is not yet valid (valid from $($cert.NotBefore))"
        exit 1
    }
    
    # Check for code signing capability
    $codeSigningEku = $cert.EnhancedKeyUsageList | Where-Object { $_.ObjectId -eq "1.3.6.1.5.5.7.3.3" }
    if (-not $codeSigningEku) {
        Write-Warning "Certificate may not have Code Signing EKU (1.3.6.1.5.5.7.3.3)"
    }
}
catch {
    Write-Error "Failed to retrieve certificate with thumbprint '$CertificateThumbprint' from Cert:\CurrentUser\My\"
    Write-Error "Use Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert to list available code signing certificates"
    exit 1
}

Write-Host ""

# Find all PowerShell files to sign
Write-Host "Discovering files to sign..." -ForegroundColor Yellow

$filesToSign = @()

# Module files
$filesToSign += Get-Item -Path "$ModuleRoot\ECMA2HostTools.psd1" -ErrorAction SilentlyContinue
$filesToSign += Get-Item -Path "$ModuleRoot\ECMA2HostTools.psm1" -ErrorAction SilentlyContinue

# All .ps1 files in subdirectories
$filesToSign += Get-ChildItem -Path "$ModuleRoot\Public" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$filesToSign += Get-ChildItem -Path "$ModuleRoot\Private" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$filesToSign += Get-ChildItem -Path "$ModuleRoot\Tests" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$filesToSign += Get-ChildItem -Path "$ModuleRoot\Examples" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue

# Remove nulls and duplicates
$filesToSign = $filesToSign | Where-Object { $null -ne $_ } | Select-Object -Unique

Write-Host "✓ Found $($filesToSign.Count) files to sign" -ForegroundColor Green
Write-Host ""

if ($filesToSign.Count -eq 0) {
    Write-Warning "No files found to sign"
    exit 0
}

# Sign each file
$signedCount = 0
$skippedCount = 0
$errorCount = 0

Write-Host "Signing files..." -ForegroundColor Yellow
Write-Host ""

foreach ($file in $filesToSign) {
    $relativePath = $file.FullName.Replace($ModuleRoot, "").TrimStart('\')
    
    if ($PSCmdlet.ShouldProcess($relativePath, "Sign with certificate")) {
        try {
            # Check current signature status
            $currentSig = Get-AuthenticodeSignature -FilePath $file.FullName
            
            if ($currentSig.Status -eq 'Valid' -and $currentSig.SignerCertificate.Thumbprint -eq $CertificateThumbprint) {
                Write-Host "  ⊘ $relativePath (already signed)" -ForegroundColor DarkGray
                $skippedCount++
                continue
            }
            
            # Sign the file
            $result = Set-AuthenticodeSignature -FilePath $file.FullName `
                                               -Certificate $cert `
                                               -TimestampServer $TimeStampServer `
                                               -ErrorAction Stop
            
            if ($result.Status -eq 'Valid') {
                Write-Host "  ✓ $relativePath" -ForegroundColor Green
                $signedCount++
            } else {
                Write-Host "  ✗ $relativePath (Status: $($result.Status))" -ForegroundColor Red
                $errorCount++
            }
        }
        catch {
            Write-Host "  ✗ $relativePath - Error: $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    } else {
        Write-Host "  ? $relativePath (WhatIf)" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  Signed: $signedCount" -ForegroundColor Green
Write-Host "  Skipped: $skippedCount" -ForegroundColor DarkGray
Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Gray' })
Write-Host ""

if ($errorCount -gt 0) {
    Write-Warning "Some files failed to sign. Review the errors above."
    exit 1
} elseif ($signedCount -gt 0) {
    Write-Host "✓ Module signing completed successfully" -ForegroundColor Green
} else {
    Write-Host "✓ No files needed signing" -ForegroundColor Green
}
