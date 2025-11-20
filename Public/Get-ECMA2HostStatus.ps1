function Get-ECMA2HostStatus {
    <#
    .SYNOPSIS
        Gets the status of the ECMA2Host service.

    .DESCRIPTION
        Retrieves the current status of the ECMA2Host service including
        service state, startup type, and basic health information.

    .PARAMETER ComputerName
        The name of the computer to check. Defaults to the local computer.

    .PARAMETER Credential
        Credentials to use when connecting to a remote computer.

    .EXAMPLE
        Get-ECMA2HostStatus
        Gets the ECMA2Host service status on the local computer.

    .EXAMPLE
        Get-ECMA2HostStatus -ComputerName "Server01"
        Gets the ECMA2Host service status on Server01.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [PSCredential]$Credential
    )

    begin {
        Write-Verbose "Getting ECMA2Host service status"
    }

    process {
        try {
            Write-Verbose "Querying ECMA2Host service on $ComputerName"
            
            # Get-Service doesn't support -ComputerName in PowerShell 5.1, only in PowerShell 6+
            # For local computer, use Get-Service directly
            if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq 'localhost' -or $ComputerName -eq '.') {
                $service = Get-Service -Name 'Microsoft ECMA2Host' -ErrorAction Stop
            }
            else {
                # For remote computers, use Get-CimInstance (works in PowerShell 5.1+)
                $cimParams = @{
                    ClassName = 'Win32_Service'
                    Filter = "Name='Microsoft ECMA2Host'"
                    ComputerName = $ComputerName
                }
                
                if ($Credential) {
                    $cimParams['Credential'] = $Credential
                }
                
                $cimService = Get-CimInstance @cimParams -ErrorAction Stop
                
                if (-not $cimService) {
                    throw "Service 'Microsoft ECMA2Host' not found on $ComputerName"
                }
                
                # Convert CIM instance to a format similar to Get-Service output
                $service = [PSCustomObject]@{
                    Name = $cimService.Name
                    DisplayName = $cimService.DisplayName
                    Status = switch ($cimService.State) {
                        'Running' { 'Running' }
                        'Stopped' { 'Stopped' }
                        'Paused' { 'Paused' }
                        default { $cimService.State }
                    }
                    StartType = $cimService.StartMode
                    CanStop = $cimService.AcceptStop
                    CanPauseAndContinue = $cimService.AcceptPause
                    DependentServices = @()
                    RequiredServices = @()
                }
            }

            # Create custom object with status information
            $status = [PSCustomObject]@{
                ComputerName = $ComputerName
                ServiceName = $service.Name
                DisplayName = $service.DisplayName
                Status = $service.Status
                StartType = $service.StartType
                CanStop = $service.CanStop
                CanPauseAndContinue = $service.CanPauseAndContinue
                DependentServices = $service.DependentServices.Count
                RequiredServices = $service.RequiredServices.Count
            }

            return $status
        }
        catch {
            Write-Error "Failed to get ECMA2Host service status on $ComputerName : $_"
        }
    }

    end {
        Write-Verbose "Get-ECMA2HostStatus operation completed"
    }
}
