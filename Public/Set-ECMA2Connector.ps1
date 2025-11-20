function Set-ECMA2Connector {
    <#
    .SYNOPSIS
        Updates ECMA2 connector parameters.

    .DESCRIPTION
        Updates one or more parameters for an ECMA2 connector by modifying the Configuration.xml file.
        Supports updating parameter values including encrypted parameters.

    .PARAMETER Name
        The name of the connector to update.

    .PARAMETER Parameters
        A hashtable of parameter names and values to update.
        Example: @{ 'Username' = 'newuser'; 'Schema Script' = 'C:\path\schema.ps1' }

    .PARAMETER AutosyncTimer
        Updates the autosync timer interval in seconds.

    .PARAMETER ConfigurationPath
        The path to the Configuration.xml file. If not specified, uses the default location:
        C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml

    .PARAMETER BackupConfiguration
        Creates a backup of the configuration file before making changes. Default is $true.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs without actually making changes.

    .PARAMETER Confirm
        Prompts for confirmation before making changes.

    .EXAMPLE
        Set-ECMA2Connector -Name "SQLConnector" -Parameters @{ 'Username' = 'newuser' }
        Updates the Username parameter for the SQLConnector connector.

    .EXAMPLE
        Set-ECMA2Connector -Name "SQLConnector" -AutosyncTimer 300
        Sets the autosync timer to 300 seconds (5 minutes).

    .EXAMPLE
        Set-ECMA2Connector -Name "SQLConnector" -Parameters @{ 
            'Schema Script' = 'C:\Scripts\schema.ps1'
            'Import Script' = 'C:\Scripts\import.ps1'
        }
        Updates multiple parameters at once.

    .EXAMPLE
        Set-ECMA2Connector -Name "SQLConnector" -Parameters @{ 'Username' = 'newuser' } -BackupConfiguration:$false
        Updates the Username without creating a backup.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter()]
        [hashtable]$Parameters,

        [Parameter()]
        [ValidateRange(1, 86400)]
        [int]$AutosyncTimer,

        [Parameter()]
        [string]$ConfigurationPath,

        [Parameter()]
        [bool]$BackupConfiguration = $true
    )

    begin {
        Write-Verbose "Starting Set-ECMA2Connector operation"
        
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
            
            # Find the connector
            $connectors = $config.Configuration.Connectors.Connector
            if ($connectors -isnot [System.Array]) {
                $connectors = @($connectors)
            }

            $connector = $connectors | Where-Object { $_.ECMAConfig.ProfileName -eq $Name }
            
            if (-not $connector) {
                Write-Error "Connector '$Name' not found in configuration"
                return
            }

            Write-Verbose "Found connector: $Name"

            # Track if any changes were made
            $changesMade = $false
            $changesDescription = @()

            # Update AutosyncTimer if specified
            if ($PSBoundParameters.ContainsKey('AutosyncTimer')) {
                if ($PSCmdlet.ShouldProcess($Name, "Update AutosyncTimer to $AutosyncTimer")) {
                    $oldValue = $connector.ECMAConfig.AutosyncTimer
                    $connector.ECMAConfig.AutosyncTimer = $AutosyncTimer.ToString()
                    $changesMade = $true
                    $changesDescription += "AutosyncTimer: $oldValue -> $AutosyncTimer"
                    Write-Verbose "Updated AutosyncTimer from $oldValue to $AutosyncTimer"
                }
            }

            # Update Parameters if specified
            if ($Parameters -and $Parameters.Count -gt 0) {
                foreach ($paramName in $Parameters.Keys) {
                    $newValue = $Parameters[$paramName]
                    
                    # Find the parameter in the connector config
                    $paramList = $connector.ConnectorConfig.Parameters.Parameter
                    if ($paramList -isnot [System.Array]) {
                        $paramList = @($paramList)
                    }

                    $param = $paramList | Where-Object { $_.Name -eq $paramName }
                    
                    if (-not $param) {
                        Write-Warning "Parameter '$paramName' not found in connector '$Name'"
                        continue
                    }

                    if ($PSCmdlet.ShouldProcess($Name, "Update parameter '$paramName'")) {
                        $oldValue = if ($param.Encrypted -eq 'true') { '[ENCRYPTED]' } else { $param.Value }
                        
                        # For encrypted parameters, note that we're updating them
                        if ($param.Encrypted -eq 'true') {
                            Write-Warning "Parameter '$paramName' is encrypted. The value will be stored as plain text in XML. Consider using the ECMA2Host configuration UI for encrypted values."
                        }
                        
                        $param.Value = $newValue.ToString()
                        $changesMade = $true
                        
                        $displayNewValue = if ($param.Encrypted -eq 'true') { '[ENCRYPTED]' } else { $newValue }
                        $changesDescription += "$paramName : $oldValue -> $displayNewValue"
                        Write-Verbose "Updated parameter '$paramName'"
                    }
                }
            }

            # Save changes if any were made
            if ($changesMade) {
                # Create backup if requested
                if ($BackupConfiguration) {
                    $backupPath = "$ConfigurationPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                    if ($PSCmdlet.ShouldProcess($backupPath, "Create backup")) {
                        Copy-Item -Path $ConfigurationPath -Destination $backupPath -Force
                        Write-Verbose "Created backup at: $backupPath"
                    }
                }

                # Save the configuration
                if ($PSCmdlet.ShouldProcess($ConfigurationPath, "Save configuration changes")) {
                    # Update ModificationDateTime
                    $connector.ECMAConfig.ModificationDateTime = (Get-Date).ToString("dddd, MMMM d, yyyy h:mm:ss tt")
                    
                    $config.Save($ConfigurationPath)
                    Write-Verbose "Configuration saved successfully"
                    
                    # Return summary of changes
                    $result = [PSCustomObject]@{
                        PSTypeName = 'ECMA2Host.ConnectorUpdate'
                        ConnectorName = $Name
                        ChangesMade = $changesMade
                        Changes = $changesDescription
                        ConfigurationPath = $ConfigurationPath
                        Timestamp = Get-Date
                    }
                    
                    Write-Host "Successfully updated connector '$Name'" -ForegroundColor Green
                    Write-Host "Changes made:" -ForegroundColor Cyan
                    foreach ($change in $changesDescription) {
                        Write-Host "  - $change" -ForegroundColor Gray
                    }
                    
                    return $result
                }
            }
            else {
                Write-Warning "No changes were specified or made"
            }
        }
        catch {
            Write-Error "Failed to update connector '$Name': $_"
        }
    }

    end {
        Write-Verbose "Set-ECMA2Connector operation completed"
    }
}
