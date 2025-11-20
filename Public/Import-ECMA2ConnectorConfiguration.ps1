function Import-ECMA2ConnectorConfiguration {
    <#
    .SYNOPSIS
        Imports an ECMA2 connector configuration.

    .DESCRIPTION
        Imports a previously exported ECMA2 connector configuration from a JSON file
        and adds it to the Configuration.xml. This function merges the connector
        into the existing configuration.

    .PARAMETER Path
        The file path of the JSON configuration export to import.

    .PARAMETER ConnectorName
        Optional name to assign to the connector. If not specified, uses the name from the file.

    .PARAMETER ConfigurationPath
        Path to the Configuration.xml file. Defaults to the standard ECMA2Host location.

    .PARAMETER ComputerName
        The name of the computer where the connector should be created.

    .PARAMETER Force
        Overwrite existing connector if it exists.

    .EXAMPLE
        Import-ECMA2ConnectorConfiguration -Path "C:\Backup\ADConnector.json"
        Imports a connector configuration from a JSON export file.

    .EXAMPLE
        Import-ECMA2ConnectorConfiguration -Path "C:\Backup\ADConnector.json" -ConnectorName "ADConnector_New" -Force
        Imports and creates a connector with a new name, overwriting if exists.

    .NOTES
        This cmdlet imports from JSON format created by Export-ECMA2ConnectorConfiguration.
        It does NOT import full XML Configuration.xml files directly.
        Use Restore-ECMA2HostConfiguration for full configuration restore.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({Test-Path $_})]
        [string]$Path,

        [Parameter()]
        [string]$ConnectorName,

        [Parameter()]
        [string]$ConfigurationPath = 'C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml',

        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Importing ECMA2 connector configuration"
    }

    process {
        try {
            # Read the JSON export file
            Write-Verbose "Reading configuration from '$Path'"
            $exportData = Get-Content -Path $Path -Raw | ConvertFrom-Json
            
            # Validate export format
            if (-not $exportData.Connector) {
                throw "Invalid export file format. Missing 'Connector' section."
            }
            
            # Determine connector name
            $targetName = if ($ConnectorName) {
                $ConnectorName
            } else {
                $exportData.Connector.Name
            }
            
            Write-Verbose "Target connector name: $targetName"
            
            # Check if configuration file exists
            if (-not (Test-Path -Path $ConfigurationPath)) {
                throw "Configuration file not found at: $ConfigurationPath"
            }
            
            # Load the XML configuration
            Write-Verbose "Loading Configuration.xml from: $ConfigurationPath"
            [xml]$config = Get-Content -Path $ConfigurationPath -ErrorAction Stop
            
            # Check if connector already exists
            $existingConnector = $config.Configuration.Connectors.Connector | 
                Where-Object { $_.ECMAConfig.ProfileName -eq $targetName }
            
            if ($existingConnector -and -not $Force) {
                throw "Connector '$targetName' already exists. Use -Force to overwrite."
            }
            
            if ($PSCmdlet.ShouldProcess($targetName, "Import connector configuration")) {
                
                # Create backup before making changes
                $backupPath = "$ConfigurationPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Write-Verbose "Creating backup at: $backupPath"
                Copy-Item -Path $ConfigurationPath -Destination $backupPath -Force
                
                # Remove existing connector if Force is specified
                if ($existingConnector) {
                    Write-Verbose "Removing existing connector '$targetName'"
                    $config.Configuration.Connectors.RemoveChild($existingConnector) | Out-Null
                }
                
                # Create new Connector element
                $newConnector = $config.CreateElement('Connector')
                
                # Create ECMAConfig section
                $ecmaConfig = $config.CreateElement('ECMAConfig')
                $ecmaConfig.AppendChild($config.CreateElement('ECMAFolderPath')).InnerText = $exportData.Connector.ECMAFolderPath
                $ecmaConfig.AppendChild($config.CreateElement('LibraryName')).InnerText = $exportData.Connector.LibraryName
                $ecmaConfig.AppendChild($config.CreateElement('AutosyncTimer')).InnerText = $exportData.Connector.AutosyncTimer
                $ecmaConfig.AppendChild($config.CreateElement('ProfileName')).InnerText = $targetName
                $ecmaConfig.AppendChild($config.CreateElement('ProfileDescription')).InnerText = $exportData.Connector.Description
                $ecmaConfig.AppendChild($config.CreateElement('CreationDateTime')).InnerText = (Get-Date).ToString('dddd, MMMM d, yyyy h:mm:ss tt')
                $ecmaConfig.AppendChild($config.CreateElement('ModificationDateTime')).InnerText = (Get-Date).ToString('dddd, MMMM d, yyyy h:mm:ss tt')
                $ecmaConfig.AppendChild($config.CreateElement('Validated')).InnerText = $exportData.Connector.Validated.ToString().ToLower()
                
                # Add SecretToken if present
                if ($exportData.Secrets -and $exportData.Secrets.SecretToken) {
                    Write-Verbose "Including SecretToken from export"
                    $ecmaConfig.AppendChild($config.CreateElement('SecretToken')).InnerText = $exportData.Secrets.SecretToken
                }
                
                $newConnector.AppendChild($ecmaConfig) | Out-Null
                
                # Create ConnectorConfig section
                $connectorConfig = $config.CreateElement('ConnectorConfig')
                
                # Add Parameters
                if ($exportData.Connector.Parameters) {
                    $parameters = $config.CreateElement('Parameters')
                    
                    foreach ($paramName in ($exportData.Connector.Parameters.PSObject.Properties.Name)) {
                        $paramData = $exportData.Connector.Parameters.$paramName
                        
                        $parameter = $config.CreateElement('Parameter')
                        $parameter.AppendChild($config.CreateElement('Name')).InnerText = $paramData.Name
                        $parameter.AppendChild($config.CreateElement('Type')).InnerText = $paramData.Type
                        $parameter.AppendChild($config.CreateElement('Use')).InnerText = $paramData.Use
                        $parameter.AppendChild($config.CreateElement('SchemaNumber')).InnerText = '1'
                        $parameter.AppendChild($config.CreateElement('Encrypted')).InnerText = $paramData.Encrypted.ToString().ToLower()
                        $parameter.AppendChild($config.CreateElement('Value')).InnerText = $paramData.Value
                        
                        $parameters.AppendChild($parameter) | Out-Null
                    }
                    
                    $connectorConfig.AppendChild($parameters) | Out-Null
                }
                
                # Add basic connector capabilities
                $connectorConfig.AppendChild($config.CreateElement('IsExportSupported')).InnerText = $exportData.Connector.IsExportSupported.ToString().ToLower()
                $connectorConfig.AppendChild($config.CreateElement('IsFullImportSupported')).InnerText = $exportData.Connector.IsFullImportSupported.ToString().ToLower()
                $connectorConfig.AppendChild($config.CreateElement('IsDeltaImportSupported')).InnerText = $exportData.Connector.IsDeltaImportSupported.ToString().ToLower()
                $connectorConfig.AppendChild($config.CreateElement('IsExportOnly')).InnerText = $exportData.Connector.IsExportOnly.ToString().ToLower()
                
                $newConnector.AppendChild($connectorConfig) | Out-Null
                
                # Create empty Schema section (placeholder - full schema import would be more complex)
                $schema = $config.CreateElement('Schema')
                $entriesSchema = $config.CreateElement('EntriesSchema')
                $schema.AppendChild($entriesSchema) | Out-Null
                $newConnector.AppendChild($schema) | Out-Null
                
                # Add the connector to the configuration
                Write-Verbose "Adding connector to Configuration.xml"
                $config.Configuration.Connectors.AppendChild($newConnector) | Out-Null
                
                # Save the configuration
                Write-Verbose "Saving configuration to: $ConfigurationPath"
                $config.Save($ConfigurationPath)
                
                Write-Verbose "Connector '$targetName' imported successfully"
                
                # Return summary
                [PSCustomObject]@{
                    PSTypeName = 'ECMA2Host.ConnectorImport'
                    ConnectorName = $targetName
                    SourceFile = $Path
                    ConfigurationPath = $ConfigurationPath
                    BackupPath = $backupPath
                    Action = if ($existingConnector) { 'Updated' } else { 'Created' }
                    Timestamp = Get-Date
                    ParameterCount = ($exportData.Connector.Parameters.PSObject.Properties.Name | Measure-Object).Count
                    IncludedSecrets = [bool]($exportData.Secrets)
                }
            }
        }
        catch {
            Write-Error "Failed to import configuration from '$Path': $_"
        }
    }

    end {
        Write-Verbose "Import-ECMA2ConnectorConfiguration operation completed"
    }
}
