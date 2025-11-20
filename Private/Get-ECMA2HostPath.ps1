function Get-ECMA2HostPath {
    <#
    .SYNOPSIS
        Gets the installation path of ECMA2Host.

    .DESCRIPTION
        Internal function to retrieve the ECMA2Host installation directory
        from the registry or common installation locations.

    .PARAMETER ComputerName
        The name of the computer to query.

    .EXAMPLE
        Get-ECMA2HostPath
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    try {
        # Common installation paths to check
        $commonPaths = @(
            "${env:ProgramFiles}\Microsoft ECMA2Host",
            "${env:ProgramFiles(x86)}\Microsoft ECMA2Host",
            "C:\Program Files\Microsoft ECMA2Host"
        )

        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                Write-Verbose "Found ECMA2Host at: $path"
                return $path
            }
        }

        # TODO: Check registry for installation path
        Write-Verbose "ECMA2Host installation path not found"
        return $null
    }
    catch {
        Write-Error "Failed to get ECMA2Host path: $_"
        return $null
    }
}
