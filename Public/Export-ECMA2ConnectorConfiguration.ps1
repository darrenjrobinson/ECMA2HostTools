function Export-ECMA2ConnectorConfiguration {
    <#
    .SYNOPSIS
        Exports an ECMA2 connector configuration.

    .DESCRIPTION
        Exports the configuration of an ECMA2 connector to a file for backup
        or migration purposes.

    .PARAMETER ConnectorName
        The name of the connector to export.

    .PARAMETER Path
        The file path where the configuration will be exported.

    .PARAMETER ComputerName
        The name of the computer where the connector is hosted.

    .PARAMETER Force
        Overwrite existing file if it exists.

    .PARAMETER ConfigurationPath
        Path to the Configuration.xml file. Defaults to the standard ECMA2Host location.

    .PARAMETER IncludeSecrets
        Include encrypted parameters and secret tokens in the export (decrypted).
        Requires Windows PowerShell 5.1 or will delegate to it automatically.

    .EXAMPLE
        Export-ECMA2ConnectorConfiguration -ConnectorName "ADConnector" -Path "C:\Backup\ADConnector.xml"
        Exports the ADConnector configuration to an XML file.

    .EXAMPLE
        Export-ECMA2ConnectorConfiguration -ConnectorName "LDAPConnector" -Path "C:\Backup\LDAPConnector.xml" -IncludeSecrets
        Exports the configuration including decrypted secrets.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]$ConnectorName,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [string]$ConfigurationPath = 'C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml',

        [Parameter()]
        [switch]$IncludeSecrets
    )

    begin {
        Write-Verbose "Exporting ECMA2 connector configuration"
    }

    process {
        try {
            # Check if file exists
            if ((Test-Path $Path) -and -not $Force) {
                Write-Error "File already exists at '$Path'. Use -Force to overwrite."
                return
            }

            if ($PSCmdlet.ShouldProcess($ConnectorName, "Export connector configuration")) {
                Write-Verbose "Exporting configuration for connector '$ConnectorName' to '$Path'"
                
                # Get connector information
                $connector = Get-ECMA2Connector -Name $ConnectorName -ConfigurationPath $ConfigurationPath -ComputerName $ComputerName
                
                if (-not $connector) {
                    throw "Connector '$ConnectorName' not found"
                }
                
                # Build export object
                $export = [ordered]@{
                    ExportInfo = [ordered]@{
                        ExportDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                        ExportedBy = $env:USERNAME
                        ComputerName = $ComputerName
                        ModuleName = 'ECMA2HostTools'
                        ModuleVersion = (Get-Module ECMA2HostTools).Version.ToString()
                    }
                    Connector = [ordered]@{
                        Name = $connector.Name
                        Description = $connector.Description
                        LibraryName = $connector.LibraryName
                        ECMAFolderPath = $connector.ECMAFolderPath
                        AutosyncTimer = $connector.AutosyncTimer
                        Validated = $connector.Validated
                        CreationDateTime = $connector.CreationDateTime
                        ModificationDateTime = $connector.ModificationDateTime
                        IsExportSupported = $connector.IsExportSupported
                        IsFullImportSupported = $connector.IsFullImportSupported
                        IsDeltaImportSupported = $connector.IsDeltaImportSupported
                        IsExportOnly = $connector.IsExportOnly
                        RunProfiles = @($connector.RunProfiles)
                        ObjectTypes = @($connector.ObjectTypes)
                        Parameters = @{}
                    }
                }
                
                # Export parameters
                if ($connector.Parameters) {
                    foreach ($paramName in $connector.Parameters.Keys) {
                        $param = $connector.Parameters[$paramName]
                        $export.Connector.Parameters[$paramName] = [ordered]@{
                            Name = $param.Name
                            Type = $param.Type
                            Use = $param.Use
                            Value = $param.Value
                            Encrypted = $param.Encrypted
                        }
                    }
                }
                
                # Include decrypted secrets if requested
                if ($IncludeSecrets) {
                    Write-Verbose "Including decrypted secrets in export"
                    try {
                        $secrets = Get-ECMA2ConnectorSecret -Name $ConnectorName -ConfigurationPath $ConfigurationPath -IncludeSecretToken -WarningAction SilentlyContinue
                        
                        if ($secrets) {
                            $export.Secrets = [ordered]@{
                                Note = 'SENSITIVE DATA - Store securely'
                                SecretToken = $secrets.SecretToken
                                EncryptedParameters = @{}
                            }
                            
                            # Handle EncryptedParameters - could be hashtable or PSCustomObject
                            $encryptedParams = $secrets.EncryptedParameters
                            if ($encryptedParams) {
                                # Get parameter names (works for both hashtable and PSCustomObject)
                                $paramNames = if ($encryptedParams -is [hashtable]) {
                                    $encryptedParams.Keys
                                } else {
                                    $encryptedParams.PSObject.Properties.Name
                                }
                                
                                # Store decrypted parameters in Secrets section
                                foreach ($paramName in $paramNames) {
                                    $param = if ($encryptedParams -is [hashtable]) {
                                        $encryptedParams[$paramName]
                                    } else {
                                        $encryptedParams.$paramName
                                    }
                                    
                                    if ($param) {
                                        $export.Secrets.EncryptedParameters[$paramName] = [ordered]@{
                                            Name = $param.Name
                                            Value = $param.Value
                                            Use = $param.Use
                                        }
                                        
                                        # Also update the value in the main Parameters section to show decrypted value
                                        if ($export.Connector.Parameters.ContainsKey($paramName)) {
                                            $export.Connector.Parameters[$paramName].Value = $param.Value
                                            $export.Connector.Parameters[$paramName].DecryptedInExport = $true
                                        }
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        Write-Warning "Failed to decrypt secrets: $_"
                    }
                }
                
                # Convert to JSON and save
                $json = $export | ConvertTo-Json -Depth 10
                
                # Ensure directory exists
                $directory = Split-Path -Path $Path -Parent
                if ($directory -and -not (Test-Path $directory)) {
                    New-Item -Path $directory -ItemType Directory -Force | Out-Null
                }
                
                # Save to file
                Set-Content -Path $Path -Value $json -Force
                
                Write-Verbose "Configuration exported successfully to '$Path'"
                
                # Return summary
                [PSCustomObject]@{
                    ConnectorName = $ConnectorName
                    ExportPath = $Path
                    ExportDate = $export.ExportInfo.ExportDate
                    IncludesSecrets = $IncludeSecrets
                    ParameterCount = $connector.Parameters.Count
                    RunProfileCount = $connector.RunProfiles.Count
                    FileSizeKB = [Math]::Round((Get-Item $Path).Length / 1KB, 2)
                }
            }
        }
        catch {
            Write-Error "Failed to export configuration for connector '$ConnectorName': $_"
        }
    }

    end {
        Write-Verbose "Export-ECMA2ConnectorConfiguration operation completed"
    }
}
