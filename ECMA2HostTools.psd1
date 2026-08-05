@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'ECMA2HostTools.psm1'

    # Version number of this module.
    ModuleVersion     = '1.2.0'

    # ID used to uniquely identify this module
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author            = 'Darren J Robinson'

    # Company or vendor of this module
    CompanyName       = 'Darren J Robinson'

    # Copyright statement for this module
    Copyright         = '(c) 2025 Darren J Robinson. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'PowerShell module for orchestrating ECMA2Host and its connectors in Microsoft Identity Manager (MIM) / FIM Sync Engine environments'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Start-ECMA2Host',
        'Stop-ECMA2Host',
        'Get-ECMA2HostStatus',
        'Get-ECMA2Connector',
        'Set-ECMA2Connector',
        'Get-ECMA2ConnectorSecret',
        'Get-ECMA2ConnectorObjects',
        'Get-ECMA2ConnectorStatus',
        'Invoke-ECMA2ConnectorRequest',
        'Get-ECMA2ConnectorRunHistory',
        'Export-ECMA2ConnectorConfiguration',
        'Import-ECMA2ConnectorConfiguration',
        'Backup-ECMA2HostConfiguration',
        'Restore-ECMA2HostConfiguration',
        'New-ECMA2ConnectorDocumentation',
        'Set-ECMA2ConnectorEncryptedParameter',
        'Connect-ECMA2Graph',
        'Disconnect-ECMA2Graph',
        'Get-ECMA2ConnectorSyncJob',
        'Restart-ECMA2ConnectorSyncJob',
        'Pause-ECMA2ConnectorSyncJob',
        'Start-ECMA2ConnectorSyncJob'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess  = @('ECMA2HostTools.Format.ps1xml')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @('ECMA2', 'ECMA2Host', 'MicrosoftEntra', 'EntraID', 'Identity', 'Connector', 'Synchronization', 'Provisioning')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/darrenjrobinson'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

            # External module dependencies
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    HelpInfoURI       = 'https://blog.darrenjrobinson.com/'
}
