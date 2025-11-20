function Get-ECMA2ConnectorStatus {
    <#
    .SYNOPSIS
        Gets the status of an ECMA2 connector.

    .DESCRIPTION
        Retrieves the current operational status of one or more ECMA2 connectors
        including running state, last run time, and health information.

    .PARAMETER Name
        The name of the connector to check. Supports wildcards.

    .PARAMETER ComputerName
        The name of the computer to query. Defaults to local computer.

    .PARAMETER ConfigurationPath
        Path to the Configuration.xml file. Defaults to the standard ECMA2Host location.

    .EXAMPLE
        Get-ECMA2ConnectorStatus -Name "ADConnector"
        Gets the status of the ADConnector.

    .EXAMPLE
        Get-ECMA2ConnectorStatus
        Gets the status of all connectors.

    .EXAMPLE
        Get-ECMA2ConnectorStatus -Name "AD*"
        Gets the status of all connectors matching the wildcard pattern.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string]$Name = "*",

        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [string]$ConfigurationPath = 'C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml'
    )

    begin {
        Write-Verbose "Getting ECMA2 connector status"
    }

    process {
        try {
            Write-Verbose "Querying status for connector '$Name' on $ComputerName"
            
            # Get all connectors from configuration
            $connectors = Get-ECMA2Connector -Name $Name -ConfigurationPath $ConfigurationPath -ComputerName $ComputerName
            
            if (-not $connectors) {
                Write-Warning "No connectors found matching '$Name'"
                return
            }
            
            # Get service status to determine if connectors can be running
            $serviceStatus = Get-ECMA2HostStatus -ComputerName $ComputerName
            
            foreach ($connector in $connectors) {
                Write-Verbose "Checking status for connector: $($connector.Name)"
                
                # Determine connector status based on service status
                $status = 'Unknown'
                $healthStatus = 'Unknown'
                
                if ($serviceStatus.Status -eq 'Running') {
                    # Service is running, connector could be active
                    # Check if autosync is enabled
                    if ($connector.AutosyncTimer -gt 0) {
                        $status = 'Autosync Enabled'
                        $healthStatus = 'Healthy'
                    }
                    else {
                        $status = 'Idle (Manual)'
                        $healthStatus = 'Healthy'
                    }
                }
                elseif ($serviceStatus.Status -eq 'Stopped') {
                    $status = 'Service Stopped'
                    $healthStatus = 'Unavailable'
                }
                elseif ($serviceStatus.Status -eq 'Paused') {
                    $status = 'Service Paused'
                    $healthStatus = 'Paused'
                }
                else {
                    $status = "Service $($serviceStatus.Status)"
                    $healthStatus = 'Warning'
                }
                
                # Check for connector cache folder to verify installation
                $isInstalled = $false
                if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq 'localhost') {
                    $isInstalled = Test-Path $connector.ECMAFolderPath -ErrorAction SilentlyContinue
                }
                
                # Build result object
                [PSCustomObject]@{
                    Name = $connector.Name
                    Status = $status
                    HealthStatus = $healthStatus
                    AutosyncTimer = $connector.AutosyncTimer
                    AutosyncEnabled = ($connector.AutosyncTimer -gt 0)
                    ServiceStatus = $serviceStatus.Status
                    Validated = $connector.Validated
                    IsInstalled = $isInstalled
                    ECMAFolderPath = $connector.ECMAFolderPath
                    Description = $connector.Description
                    RunProfiles = $connector.RunProfiles
                    ComputerName = $ComputerName
                }
            }
        }
        catch {
            Write-Error "Failed to get connector status for '$Name': $_"
        }
    }

    end {
        Write-Verbose "Get-ECMA2ConnectorStatus operation completed"
    }
}
