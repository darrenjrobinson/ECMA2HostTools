function Get-ECMA2Connector {
    <#
    .SYNOPSIS
        Gets ECMA2 connector information.

    .DESCRIPTION
        Retrieves information about ECMA2 connectors configured in the system by reading
        the Configuration.xml file. Can filter by connector name or return all connectors.

    .PARAMETER Name
        The name of the connector to retrieve. Supports wildcards.

    .PARAMETER ConfigurationPath
        The path to the Configuration.xml file. If not specified, uses the default location:
        C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml

    .PARAMETER ComputerName
        The name of the computer to query. Defaults to the local computer.

    .EXAMPLE
        Get-ECMA2Connector
        Gets all ECMA2 connectors from the default configuration location.

    .EXAMPLE
        Get-ECMA2Connector -Name "AD*"
        Gets all connectors whose names start with "AD".

    .EXAMPLE
        Get-ECMA2Connector -ConfigurationPath "D:\CustomPath\Configuration.xml"
        Gets all connectors from a custom configuration path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string]$Name = "*",

        [Parameter()]
        [string]$ConfigurationPath,

        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    begin {
        Write-Verbose "Getting ECMA2 connector information"
        
        # Set default configuration path if not provided
        if ([string]::IsNullOrEmpty($ConfigurationPath)) {
            $ConfigurationPath = "C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml"
            Write-Verbose "Using default configuration path: $ConfigurationPath"
        }
    }

    process {
        try {
            # Check if configuration file exists
            if (-not (Test-Path -Path $ConfigurationPath)) {
                Write-Error "Configuration file not found at: $ConfigurationPath"
                return
            }

            Write-Verbose "Reading configuration from: $ConfigurationPath"
            
            # Load the XML configuration
            [xml]$config = Get-Content -Path $ConfigurationPath -ErrorAction Stop
            
            # Check if there are any connectors defined
            if (-not $config.Configuration.Connectors) {
                Write-Warning "No connectors found in the XML file"
                return @()
            }

            # Get all connector configurations
            $connectors = $config.Configuration.Connectors.Connector
            
            if (-not $connectors) {
                Write-Verbose "No connectors found in configuration"
                return @()
            }

            # Ensure connectors is always an array
            if ($connectors -isnot [System.Array]) {
                $connectors = @($connectors)
            }

            Write-Verbose "Found $($connectors.Count) connector(s) in configuration"

            # Filter by name if specified (using ProfileName from ECMAConfig)
            $filteredConnectors = $connectors | Where-Object {
                $_.ECMAConfig.ProfileName -like $Name
            }

            # Create custom objects with connector information
            $results = foreach ($connector in $filteredConnectors) {
                # Build parameters hashtable
                $parametersHash = @{}
                if ($connector.ConnectorConfig.Parameters.Parameter) {
                    $paramList = $connector.ConnectorConfig.Parameters.Parameter
                    if ($paramList -isnot [System.Array]) {
                        $paramList = @($paramList)
                    }
                    
                    foreach ($param in $paramList) {
                        $parametersHash[$param.Name] = [PSCustomObject]@{
                            Name = $param.Name
                            Type = $param.Type
                            Use = $param.Use
                            Value = if ($param.Encrypted -eq 'true') { '[ENCRYPTED]' } else { $param.Value }
                            Encrypted = [bool]::Parse($param.Encrypted)
                        }
                    }
                }

                [PSCustomObject]@{
                    PSTypeName = 'ECMA2Host.Connector'
                    Name = $connector.ECMAConfig.ProfileName
                    Description = $connector.ECMAConfig.ProfileDescription
                    LibraryName = $connector.ECMAConfig.LibraryName
                    ECMAFolderPath = $connector.ECMAConfig.ECMAFolderPath
                    AutosyncTimer = $connector.ECMAConfig.AutosyncTimer
                    Validated = if ($connector.ECMAConfig.Validated) { [bool]::Parse($connector.ECMAConfig.Validated) } else { $false }
                    CreationDateTime = $connector.ECMAConfig.CreationDateTime
                    ModificationDateTime = $connector.ECMAConfig.ModificationDateTime
                    IsExportSupported = if ($connector.ConnectorConfig.IsExportSupported) { [bool]::Parse($connector.ConnectorConfig.IsExportSupported) } else { $false }
                    IsFullImportSupported = if ($connector.ConnectorConfig.IsFullImportSupported) { [bool]::Parse($connector.ConnectorConfig.IsFullImportSupported) } else { $false }
                    IsDeltaImportSupported = if ($connector.ConnectorConfig.IsDeltaImportSupported) { [bool]::Parse($connector.ConnectorConfig.IsDeltaImportSupported) } else { $false }
                    IsExportOnly = if ($connector.ConnectorConfig.IsExportOnly) { [bool]::Parse($connector.ConnectorConfig.IsExportOnly) } else { $false }
                    RunProfiles = @($connector.ConnectorConfig.RunConfigurations.RunConfiguration | ForEach-Object { $_.Name })
                    ObjectTypes = @($connector.Schema.EntriesSchema.EntrySchema | ForEach-Object { $_.ObjectType })
                    Parameters = $parametersHash
                    ComputerName = $ComputerName
                    ConfigurationPath = $ConfigurationPath
                }
            }

            Write-Verbose "Returning $($results.Count) connector(s) matching filter '$Name'"
            return $results
        }
        catch {
            Write-Error "Failed to get ECMA2 connector information: $_"
        }
    }

    end {
        Write-Verbose "Get-ECMA2Connector operation completed"
    }
}
