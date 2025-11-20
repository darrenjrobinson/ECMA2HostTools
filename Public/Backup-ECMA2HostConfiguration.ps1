function Backup-ECMA2HostConfiguration {
    <#
    .SYNOPSIS
        Backs up the complete ECMA2Host configuration.

    .DESCRIPTION
        Creates a complete backup of the ECMA2Host Configuration.xml file including
        all connectors and host settings (Port, Certificate).

    .PARAMETER Path
        The file path where the backup will be saved.

    .PARAMETER ConfigurationPath
        Path to the Configuration.xml file. Defaults to the standard ECMA2Host location.

    .PARAMETER ComputerName
        The name of the computer where the configuration is located.

    .PARAMETER Force
        Overwrite existing file if it exists.

    .EXAMPLE
        Backup-ECMA2HostConfiguration -Path "C:\Backups\ECMA2Host_20250117.xml"
        Creates a complete backup of the ECMA2Host configuration.

    .EXAMPLE
        Backup-ECMA2HostConfiguration -Path "C:\Backups\Full_Backup.xml" -Force
        Creates a backup, overwriting any existing file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$ConfigurationPath = 'C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml',

        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Starting ECMA2Host configuration backup"
    }

    process {
        try {
            # Check if source configuration exists
            if (-not (Test-Path -Path $ConfigurationPath)) {
                throw "Configuration file not found at: $ConfigurationPath"
            }

            # Check if destination file exists
            if ((Test-Path $Path) -and -not $Force) {
                throw "File already exists at '$Path'. Use -Force to overwrite."
            }

            if ($PSCmdlet.ShouldProcess($ConfigurationPath, "Backup ECMA2Host configuration")) {
                Write-Verbose "Backing up configuration from: $ConfigurationPath"
                
                # Ensure destination directory exists
                $directory = Split-Path -Path $Path -Parent
                if ($directory -and -not (Test-Path $directory)) {
                    New-Item -Path $directory -ItemType Directory -Force | Out-Null
                }
                
                # Copy the configuration file
                Copy-Item -Path $ConfigurationPath -Destination $Path -Force
                
                Write-Verbose "Configuration backed up successfully to: $Path"
                
                # Load and analyze the backup
                [xml]$config = Get-Content -Path $Path
                
                $connectorCount = 0
                if ($config.Configuration.Connectors.Connector) {
                    $connectors = $config.Configuration.Connectors.Connector
                    $connectorCount = if ($connectors -is [System.Array]) { $connectors.Count } else { 1 }
                }
                
                # Return summary
                [PSCustomObject]@{
                    PSTypeName = 'ECMA2Host.ConfigurationBackup'
                    BackupPath = $Path
                    SourcePath = $ConfigurationPath
                    BackupDate = Get-Date
                    ConnectorCount = $connectorCount
                    Port = $config.Configuration.Setting.Port
                    CertificateThumbprint = $config.Configuration.Setting.Certificate
                    FileSizeKB = [Math]::Round((Get-Item $Path).Length / 1KB, 2)
                    ComputerName = $ComputerName
                }
            }
        }
        catch {
            Write-Error "Failed to backup ECMA2Host configuration: $_"
        }
    }

    end {
        Write-Verbose "Backup-ECMA2HostConfiguration operation completed"
    }
}
