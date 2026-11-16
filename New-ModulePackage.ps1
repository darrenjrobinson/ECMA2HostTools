<#
.SYNOPSIS
Stage the publishable module folder.

.DESCRIPTION
Copies the files that ship with the module into <Destination>/ECMA2HostTools and returns that
folder's path. Tests, examples, build scripts and local-only documents are left out. The folder
can be published with Publish-PSResource -Path <folder>.

.PARAMETER Destination
Folder to stage the module under. Defaults to a folder in the system temp directory.

.EXAMPLE
PS> $package = ./New-ModulePackage.ps1
#>
[CmdletBinding()]
param (
    [string]$Destination = (Join-Path ([IO.Path]::GetTempPath()) 'ECMA2HostTools-package')
)

$ErrorActionPreference = 'Stop'

$moduleName = 'ECMA2HostTools'
$root = $PSScriptRoot
$staging = Join-Path $Destination $moduleName

if (Test-Path $staging) {
    Remove-Item -Path $staging -Recurse -Force
}
New-Item -ItemType Directory -Path $staging -Force | Out-Null

$required = @(
    "$moduleName.psd1",
    "$moduleName.psm1",
    "$moduleName.Format.ps1xml",
    'Public',
    'Private'
)
$optional = @('README.md', 'CHANGELOG.md', 'LICENSE')

foreach ($item in $required + $optional) {
    $source = Join-Path $root $item
    if (-not (Test-Path $source)) {
        if ($item -in $required) {
            throw "Required module file not found: $item"
        }
        continue
    }
    Copy-Item -Path $source -Destination $staging -Recurse -Force
}

return $staging
