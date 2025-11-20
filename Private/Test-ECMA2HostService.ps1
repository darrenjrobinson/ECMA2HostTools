function Test-ECMA2HostService {
    <#
    .SYNOPSIS
        Tests if the ECMA2Host service is installed and accessible.

    .DESCRIPTION
        Internal function to verify that the ECMA2Host service exists
        and is accessible on the specified computer.

    .PARAMETER ComputerName
        The name of the computer to check.

    .EXAMPLE
        Test-ECMA2HostService
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    try {
        $service = Get-Service -Name 'ECMA2Host' -ComputerName $ComputerName -ErrorAction SilentlyContinue
        
        if ($service) {
            Write-Verbose "ECMA2Host service found on $ComputerName"
            return $true
        }
        else {
            Write-Verbose "ECMA2Host service not found on $ComputerName"
            return $false
        }
    }
    catch {
        Write-Error "Failed to test ECMA2Host service: $_"
        return $false
    }
}
