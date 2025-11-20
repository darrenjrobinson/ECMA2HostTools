function Restore-ECMA2HostConfiguration {
    <#
    .SYNOPSIS
        Restores a complete ECMA2Host configuration.

    .DESCRIPTION
        Restores a previously backed up ECMA2Host Configuration.xml file including
        all connectors and host settings. This completely replaces the current configuration.

    .PARAMETER Path
        The file path of the backup configuration to restore.

    .PARAMETER ConfigurationPath
        Path to the Configuration.xml file. Defaults to the standard ECMA2Host location.

    .PARAMETER ComputerName
        The name of the computer where the configuration should be restored.

    .PARAMETER Force
        Skip confirmation prompt and proceed with restore.

    .PARAMETER RestartService
        Restart the ECMA2Host service after restore to apply changes.

    .EXAMPLE
        Restore-ECMA2HostConfiguration -Path "C:\Backups\ECMA2Host_20250117.xml"
        Restores the complete ECMA2Host configuration from a backup file.

    .EXAMPLE
        Restore-ECMA2HostConfiguration -Path "C:\Backups\Full_Backup.xml" -RestartService -Force
        Restores configuration and restarts the service without confirmation.

    .NOTES
        WARNING: This cmdlet completely replaces the current Configuration.xml file.
        A backup of the current configuration is automatically created before restore.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$Path,

        [Parameter()]
        [string]$ConfigurationPath = 'C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml',

        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$RestartService
    )

    begin {
        Write-Verbose "Starting ECMA2Host configuration restore"
    }

    process {
        try {
            # Validate backup file
            Write-Verbose "Validating backup file: $Path"
            [xml]$backupConfig = Get-Content -Path $Path -ErrorAction Stop
            
            if (-not $backupConfig.Configuration) {
                throw "Invalid configuration file format. Missing 'Configuration' root element."
            }
            
            # Analyze backup
            $connectorCount = 0
            if ($backupConfig.Configuration.Connectors.Connector) {
                $connectors = $backupConfig.Configuration.Connectors.Connector
                $connectorCount = if ($connectors -is [System.Array]) { $connectors.Count } else { 1 }
            }
            
            Write-Verbose "Backup contains $connectorCount connector(s)"
            
            # Check if current configuration exists
            $currentExists = Test-Path -Path $ConfigurationPath
            
            if ($PSCmdlet.ShouldProcess($ConfigurationPath, "Restore ECMA2Host configuration from $Path")) {
                
                # Create backup of current configuration if it exists
                if ($currentExists) {
                    $backupPath = "$ConfigurationPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                    Write-Verbose "Creating backup of current configuration at: $backupPath"
                    Copy-Item -Path $ConfigurationPath -Destination $backupPath -Force
                    Write-Warning "Current configuration backed up to: $backupPath"
                } else {
                    Write-Verbose "No existing configuration found"
                }
                
                # Ensure destination directory exists
                $directory = Split-Path -Path $ConfigurationPath -Parent
                if ($directory -and -not (Test-Path $directory)) {
                    New-Item -Path $directory -ItemType Directory -Force | Out-Null
                }
                
                # Restore the configuration
                Write-Verbose "Restoring configuration to: $ConfigurationPath"
                Copy-Item -Path $Path -Destination $ConfigurationPath -Force
                
                Write-Verbose "Configuration restored successfully"
                
                # Restart service if requested
                if ($RestartService) {
                    Write-Verbose "Restarting ECMA2Host service"
                    try {
                        Stop-ECMA2Host -ComputerName $ComputerName -ErrorAction Stop
                        Start-Sleep -Seconds 2
                        Start-ECMA2Host -ComputerName $ComputerName -ErrorAction Stop
                        Write-Verbose "ECMA2Host service restarted successfully"
                    }
                    catch {
                        Write-Warning "Failed to restart ECMA2Host service: $_"
                        Write-Warning "You may need to restart the service manually for changes to take effect."
                    }
                }
                else {
                    Write-Warning "ECMA2Host service was not restarted. Restart the service for changes to take effect."
                }
                
                # Return summary
                [PSCustomObject]@{
                    PSTypeName = 'ECMA2Host.ConfigurationRestore'
                    RestoredFrom = $Path
                    RestoredTo = $ConfigurationPath
                    RestoreDate = Get-Date
                    ConnectorCount = $connectorCount
                    Port = $backupConfig.Configuration.Setting.Port
                    CertificateThumbprint = $backupConfig.Configuration.Setting.Certificate
                    ServiceRestarted = $RestartService
                    BackupCreated = if ($currentExists) { $backupPath } else { 'N/A - No existing configuration' }
                    ComputerName = $ComputerName
                }
            }
        }
        catch {
            Write-Error "Failed to restore ECMA2Host configuration: $_"
        }
    }

    end {
        Write-Verbose "Restore-ECMA2HostConfiguration operation completed"
    }
}
