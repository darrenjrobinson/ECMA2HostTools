function Set-ECMA2ConnectorEncryptedParameter {
    <#
    .SYNOPSIS
        Sets an encrypted parameter value for an ECMA2 connector.

    .DESCRIPTION
        Updates an encrypted parameter (such as passwords) for an ECMA2 connector by encrypting
        the value using Windows DPAPI with LocalMachine scope and updating the Configuration.xml.
        
        IMPORTANT: This cmdlet MUST be executed locally on the ECMA2Host server where the connector
        is configured, or via Invoke-Command to that server. DPAPI encryption is machine-specific
        and encrypted values can only be used on the machine where they were created.

    .PARAMETER Name
        The name of the connector to update.

    .PARAMETER ParameterName
        The name of the encrypted parameter to set (e.g., "Password", "Password (auxiliary)", "SecretToken").
        Note: SecretToken is stored in ECMAConfig and will be created if it doesn't exist.

    .PARAMETER Value
        The plaintext value to encrypt and store. This will be encrypted using DPAPI LocalMachine scope.
        For SecretToken, use the same GUID value on all ECMA2Host servers that connect to the same Entra application.

    .PARAMETER ConfigurationPath
        Path to the Configuration.xml file. Defaults to the standard ECMA2Host location.

    .EXAMPLE
        Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password" -Value "SecureP@ssw0rd123"
        Sets the Password parameter for the SQLConnector on the local machine.

    .EXAMPLE
        # Remote execution via PowerShell remoting
        Invoke-Command -ComputerName "EcmaServer" -ScriptBlock {
            Import-Module ECMA2HostTools
            Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password" -Value "SecureP@ssw0rd123"
        }

    .EXAMPLE
        # Automated deployment with password from vault
        $password = Get-Secret -Name "SQL-Service-Account" -AsPlainText
        Invoke-Command -ComputerName "EcmaServer" -ScriptBlock {
            param($pwd)
            Import-Module ECMA2HostTools
            Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "Password" -Value $pwd
        } -ArgumentList $password

    .EXAMPLE
        # Pipeline from Get-ECMA2Connector
        Get-ECMA2Connector -Name "SQLConnector" | 
            Set-ECMA2ConnectorEncryptedParameter -ParameterName "Password" -Value "SecureP@ssw0rd123"

    .EXAMPLE
        # Set SecretToken for a connector (use same value on all servers connecting to same Entra app)
        $secretToken = "12345678-abcd-ef12-3456-7890abcdef12"
        Set-ECMA2ConnectorEncryptedParameter -Name "SQLConnector" -ParameterName "SecretToken" -Value $secretToken

    .NOTES
        This cmdlet must run on Windows PowerShell 5.1 or be delegated to it from PowerShell 7+
        because DPAPI encryption requires the .NET Framework implementation.
        
        The cmdlet will automatically create a backup of Configuration.xml before making changes.
        
        After updating encrypted parameters, you should restart the ECMA2Host service for
        changes to take effect.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ParameterName,

        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter()]
        [string]$ConfigurationPath = 'C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml'
    )

    begin {
        Write-Verbose "Set-ECMA2ConnectorEncryptedParameter starting"
        
        # Check if running on Windows
        if (-not $IsWindows -and $null -ne $IsWindows) {
            throw "This cmdlet requires Windows operating system for DPAPI encryption"
        }
        
        # Verify we're running on the local machine (not via network path)
        if ($ConfigurationPath -match '^\\\\' -or $ConfigurationPath -match '^[A-Z]:' -and $ConfigurationPath -notmatch '^C:') {
            Write-Warning "Configuration path appears to be remote. DPAPI encryption is machine-specific and will only work on the local ECMA2Host server."
            Write-Warning "If you're trying to configure a remote server, use Invoke-Command to run this cmdlet ON that server."
        }
        
        # Check PowerShell version - we need to use Windows PowerShell 5.1 for ECMA2Host encryption
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Write-Verbose "Running in PowerShell 7+, will delegate to Windows PowerShell 5.1"
            $script:UseWindowsPowerShell = $true
        }
        else {
            Write-Verbose "Running in Windows PowerShell $($PSVersionTable.PSVersion)"
            $script:UseWindowsPowerShell = $false
            
            # Load the ECMA2Host encryption assembly
            $ecmaHostPath = 'C:\Program Files\Microsoft ECMA2Host\Service'
            $encryptedDll = Join-Path $ecmaHostPath 'Microsoft.ECMA2Host.Encrypted.dll'
            
            if (-not (Test-Path $encryptedDll)) {
                throw "Microsoft.ECMA2Host.Encrypted.dll not found at: $encryptedDll. Ensure ECMA2Host is installed."
            }

            try {
                # Load the assembly
                $script:Assembly = [System.Reflection.Assembly]::LoadFrom($encryptedDll)
                
                # Get all types in the assembly
                $types = $script:Assembly.GetTypes()
                Write-Verbose "Found types in assembly: $($types.FullName -join ', ')"
                
                # Look for types with encryption methods
                foreach ($type in $types) {
                    $encryptMethods = $type.GetMethods([System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static) | 
                        Where-Object { $_.Name -match 'Encrypt' -and -not ($_.Name -match 'Decrypt') }
                    if ($encryptMethods) {
                        Write-Verbose "Type $($type.Name) has encryption methods: $($encryptMethods.Name -join ', ')"
                        $script:EncryptType = $type
                        break
                    }
                }
                
                # Also keep EncryptTools for reference
                $script:EncryptToolsType = $script:Assembly.GetType('Microsoft.ECMA2Host.Encrypted.EncryptTools')
                
                Write-Verbose "Loaded ECMA2Host encryption assembly"
            }
            catch {
                throw "Failed to load ECMA2Host encryption assembly: $_"
            }
        }
    }

    process {
        try {
            # Get the connector
            Write-Verbose "Loading connector '$Name' from configuration"
            $connector = Get-ECMA2Connector -Name $Name -ConfigurationPath $ConfigurationPath -ErrorAction Stop
            
            if (-not $connector) {
                throw "Connector '$Name' not found in configuration"
            }

            # Special handling for SecretToken (it's in ECMAConfig, not Parameters)
            $isSecretToken = $ParameterName -eq 'SecretToken'
            
            if (-not $isSecretToken) {
                # Check if the parameter exists in the connector
                $paramExists = $connector.Parameters.PSObject.Properties.Name -contains $ParameterName
                if (-not $paramExists) {
                    throw "Parameter '$ParameterName' not found in connector '$Name'. Available parameters: $($connector.Parameters.PSObject.Properties.Name -join ', ')"
                }

                # Verify the parameter is supposed to be encrypted
                $param = $connector.Parameters.$ParameterName
                if ($param.Type -notin @('EncryptedString', 'Password')) {
                    Write-Warning "Parameter '$ParameterName' is of type '$($param.Type)'. This cmdlet is intended for encrypted parameters (EncryptedString/Password types)."
                }
            }
            else {
                Write-Verbose "Setting SecretToken (ECMAConfig element)"
                Write-Verbose "SecretToken value will be serialized and encrypted for this machine"
            }

            if ($PSCmdlet.ShouldProcess("$Name/$ParameterName", "Set encrypted parameter value")) {
                
                # Delegate to Windows PowerShell 5.1 if running in PowerShell 7+
                if ($script:UseWindowsPowerShell) {
                    Write-Verbose "Delegating encryption to Windows PowerShell 5.1"
                    
                    # Build command to run in Windows PowerShell 5.1
                    $modulePath = Split-Path -Parent $PSScriptRoot
                    $manifestPath = Join-Path $modulePath 'ECMA2HostTools.psd1'
                    
                    # Escape special characters in the value
                    $escapedValue = $Value -replace "'", "''"
                    
                    $ps51Command = @"
Import-Module '$manifestPath' -Force -WarningAction SilentlyContinue
Set-ECMA2ConnectorEncryptedParameter -Name '$Name' -ParameterName '$ParameterName' -Value '$escapedValue' -ConfigurationPath '$ConfigurationPath' -Verbose:`$$($VerbosePreference -eq 'Continue') | ConvertTo-Json -Depth 5 -Compress
"@
                    
                    $result = powershell.exe -NoProfile -NonInteractive -Command $ps51Command 2>&1
                    
                    # Filter out error messages to get only JSON
                    $jsonOutput = $result | Where-Object { $_ -is [string] -and $_ -match '^\{' }
                    
                    if (-not $jsonOutput) {
                        $errorMessages = $result | Where-Object { $_ -isnot [string] -or $_ -notmatch '^\{' }
                        throw "Failed to encrypt in Windows PowerShell 5.1. Errors: $($errorMessages -join '; ')"
                    }
                    
                    $returnObject = $jsonOutput | ConvertFrom-Json
                    return $returnObject
                }
                
                # Running in Windows PowerShell 5.1 - use DPAPI encryption with BinaryFormatter
                Write-Verbose "Encrypting value using DPAPI with BinaryFormatter serialization"
                
                try {
                    Add-Type -AssemblyName System.Security
                    
                    if ($isSecretToken) {
                        # SecretToken requires BinaryFormatter serialization
                        Write-Verbose "Using BinaryFormatter serialization for SecretToken"
                        
                        # Create a MemoryStream and BinaryFormatter
                        $memStream = New-Object System.IO.MemoryStream
                        $formatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
                        
                        # Serialize the string value
                        $formatter.Serialize($memStream, $Value)
                        $serializedBytes = $memStream.ToArray()
                        $memStream.Close()
                        
                        Write-Verbose "Serialized to $($serializedBytes.Length) bytes"
                        
                        # Encrypt using DPAPI LocalMachine scope
                        $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
                            $serializedBytes,
                            $null,
                            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
                        )
                        
                        $encryptedValue = [Convert]::ToBase64String($encryptedBytes)
                        Write-Verbose "Encrypted to $($encryptedBytes.Length) bytes, Base64 length: $($encryptedValue.Length)"
                    }
                    else {
                        # Regular parameters - just encrypt the UTF8 bytes
                        Write-Verbose "Using simple UTF8 encryption for password parameter"
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
                        $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
                            $bytes,
                            $null,
                            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
                        )
                        $encryptedValue = [Convert]::ToBase64String($encryptedBytes)
                    }
                    
                    Write-Verbose "Value encrypted successfully"
                }
                catch {
                    throw "Failed to encrypt value using DPAPI: $_"
                }
                
                # Load the XML configuration
                Write-Verbose "Loading Configuration.xml from: $ConfigurationPath"
                $config = New-Object System.Xml.XmlDocument
                $config.Load($ConfigurationPath)
                
                # Create backup
                $backupPath = "$ConfigurationPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Write-Verbose "Creating backup at: $backupPath"
                Copy-Item -Path $ConfigurationPath -Destination $backupPath -Force
                
                # Find the connector using XPath
                $connectorNode = $config.SelectSingleNode("//Connector[ECMAConfig/ProfileName='$Name']")
                if (-not $connectorNode) {
                    throw "Could not locate connector '$Name' in XML configuration"
                }
                
                if ($isSecretToken) {
                    # SecretToken is stored in ECMAConfig, not Parameters
                    Write-Verbose "Setting SecretToken in ECMAConfig"
                    $ecmaConfigNode = $connectorNode.SelectSingleNode('ECMAConfig')
                    $secretTokenNode = $ecmaConfigNode.SelectSingleNode('SecretToken')
                    
                    if ($secretTokenNode) {
                        Write-Verbose "Updating existing SecretToken"
                        $secretTokenNode.InnerText = $encryptedValue
                    }
                    else {
                        Write-Verbose "Creating new SecretToken node"
                        $secretTokenNode = $config.CreateElement('SecretToken')
                        $secretTokenNode.InnerText = $encryptedValue
                        # Insert after AutosyncTimer or ProfileName
                        $autoSyncNode = $ecmaConfigNode.SelectSingleNode('AutosyncTimer')
                        if ($autoSyncNode) {
                            $ecmaConfigNode.InsertAfter($secretTokenNode, $autoSyncNode) | Out-Null
                        }
                        else {
                            $ecmaConfigNode.AppendChild($secretTokenNode) | Out-Null
                        }
                    }
                }
                else {
                    # Regular parameter in ConnectorConfig/Parameters
                    Write-Verbose "Setting parameter '$ParameterName' in ConnectorConfig/Parameters"
                    $paramNode = $connectorNode.SelectSingleNode("ConnectorConfig/Parameters/Parameter[Name='$ParameterName']")
                    if (-not $paramNode) {
                        throw "Could not locate parameter '$ParameterName' in connector '$Name'"
                    }
                    
                    # Update the parameter value and ensure it's marked as encrypted
                    $valueNode = $paramNode.SelectSingleNode('Value')
                    $encryptedNode = $paramNode.SelectSingleNode('Encrypted')
                    
                    if ($valueNode) {
                        Write-Verbose "Updating parameter value"
                        $valueNode.InnerText = $encryptedValue
                    }
                    else {
                        Write-Verbose "Creating Value node"
                        $valueNode = $config.CreateElement('Value')
                        $valueNode.InnerText = $encryptedValue
                        $paramNode.AppendChild($valueNode) | Out-Null
                    }
                    
                    if ($encryptedNode) {
                        $encryptedNode.InnerText = 'true'
                    }
                    else {
                        Write-Verbose "Creating Encrypted node"
                        $encryptedNode = $config.CreateElement('Encrypted')
                        $encryptedNode.InnerText = 'true'
                        $paramNode.AppendChild($encryptedNode) | Out-Null
                    }
                }
                
                # Save the configuration
                Write-Verbose "Saving configuration to: $ConfigurationPath"
                $config.Save($ConfigurationPath)
                
                Write-Verbose "Parameter '$ParameterName' updated successfully"
                
                # Return summary
                [PSCustomObject]@{
                    PSTypeName = 'ECMA2Host.EncryptedParameterUpdate'
                    ConnectorName = $Name
                    ParameterName = $ParameterName
                    ConfigurationPath = $ConfigurationPath
                    BackupPath = $backupPath
                    Timestamp = Get-Date
                    ComputerName = $env:COMPUTERNAME
                    Success = $true
                }
            }
        }
        catch {
            Write-Error "Failed to set encrypted parameter '$ParameterName' for connector '$Name': $_"
            
            [PSCustomObject]@{
                PSTypeName = 'ECMA2Host.EncryptedParameterUpdate'
                ConnectorName = $Name
                ParameterName = $ParameterName
                ConfigurationPath = $ConfigurationPath
                BackupPath = $null
                Timestamp = Get-Date
                ComputerName = $env:COMPUTERNAME
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }

    end {
        Write-Verbose "Set-ECMA2ConnectorEncryptedParameter completed"
    }
}

# SIG # Begin signature block
# MIIoYgYJKoZIhvcNAQcCoIIoUzCCKE8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBSBVP9w+V2dw+C
# 758D1SCw/yOgTmH7dJ/tIn9+PPgdnqCCIV8wggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggawMIIEmKADAgECAhAIrUCyYNKcTJ9ezam9k67ZMA0GCSqG
# SIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRy
# dXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0zNjA0MjgyMzU5NTlaMGkx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEzODQg
# MjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDVtC9C0Cit
# eLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0JAfhS0/TeEP0F9ce2vnS
# 1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJrQ5qZ8sU7H/Lvy0daE6ZM
# swEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhFLqGfLOEYwhrMxe6TSXBC
# Mo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+FLEikVoQ11vkunKoAFdE3
# /hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh3K3kGKDYwSNHR7OhD26j
# q22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJwZPt4bRc4G/rJvmM1bL5
# OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQayg9Rc9hUZTO1i4F4z8ujo
# 7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbIYViY9XwCFjyDKK05huzU
# tw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchApQfDVxW0mdmgRQRNYmtwm
# KwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRroOBl8ZhzNeDhFMJlP/2NP
# TLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IBWTCCAVUwEgYDVR0TAQH/
# BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+YXsIiGX0TkIwHwYDVR0j
# BBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0
# cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8E
# PDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAEDMAgGBmeBDAEEATANBgkq
# hkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql+Eg08yy25nRm95RysQDK
# r2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFFUP2cvbaF4HZ+N3HLIvda
# qpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1hmYFW9snjdufE5BtfQ/g+
# lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3RywYFzzDaju4ImhvTnhOE7a
# brs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5UbdldAhQfQDN8A+KVssIhdXNS
# y0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw8MzK7/0pNVwfiThV9zeK
# iwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnPLqR0kq3bPKSchh/jwVYb
# KyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatEQOON8BUozu3xGFYHKi8Q
# xAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bnKD+sEq6lLyJsQfmCXBVm
# zGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQjiWQ1tygVQK+pKHJ6l/aCn
# HwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbqyK+p/pQd52MbOoZWeE4w
# gga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBH
# NDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1
# c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48RsAcrHXbo0Zo
# dLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi
# 6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNg
# xVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFiDNYiOTx4OtiF
# cMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZvkgFkriK9tUKJ
# m/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLeGkuAhHiGPMvS
# GmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1
# ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9
# MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36czwzsucuoKs7
# Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bG
# RinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6
# X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAd
# BgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJx
# XWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGln
# aWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJo
# dHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNy
# bDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQEL
# BQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxj
# aaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU/kXjjytJgnn0
# hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKChHyfpzee5kH0
# F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8dTXqvcnT
# mpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKf
# ZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qIijanrUR3anzE
# wlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbh
# OhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEBYTptMSbhdhGQDpOX
# gpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWsWCiKi9EO
# LLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wG
# WqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdcMIIG7TCCBNWg
# AwIBAgIQCoDvGEuN8QWC0cR2p5V0aDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0
# IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0Ex
# MB4XDTI1MDYwNDAwMDAwMFoXDTM2MDkwMzIzNTk1OVowYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBTSEEy
# NTYgUlNBNDA5NiBUaW1lc3RhbXAgUmVzcG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBANBGrC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3
# zBlCMGMyqJnfFNZx+wvA69HFTBdwbHwBSOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8Tch
# TySA2R4QKpVD7dvNZh6wW2R6kSu9RJt/4QhguSssp3qome7MrxVyfQO9sMx6ZAWj
# FDYOzDi8SOhPUWlLnh00Cll8pjrUcCV3K3E0zz09ldQ//nBZZREr4h/GI6Dxb2Uo
# yrN0ijtUDVHRXdmncOOMA3CoB/iUSROUINDT98oksouTMYFOnHoRh6+86Ltc5zjP
# KHW5KqCvpSduSwhwUmotuQhcg9tw2YD3w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KS
# uNLoZLc1Hf2JNMVL4Q1OpbybpMe46YceNA0LfNsnqcnpJeItK/DhKbPxTTuGoX7w
# JNdoRORVbPR1VVnDuSeHVZlc4seAO+6d2sC26/PQPdP51ho1zBp+xUIZkpSFA8vW
# doUoHLWnqWU3dCCyFG1roSrgHjSHlq8xymLnjCbSLZ49kPmk8iyyizNDIXj//cOg
# rY7rlRyTlaCCfw7aSUROwnu7zER6EaJ+AliL7ojTdS5PWPsWeupWs7NpChUk555K
# 096V1hE0yZIXe+giAwW00aHzrDchIc2bQhpp0IoKRR7YufAkprxMiXAJQ1XCmnCf
# gPf8+3mnAgMBAAGjggGVMIIBkTAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zy
# Me39/dfzkXFjGVBDz2GM6DAfBgNVHSMEGDAWgBTvb1NK6eQGfHrK4pBW9i/USezL
# TjAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsG
# AQUFBwEBBIGIMIGFMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wXQYIKwYBBQUHMAKGUWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNy
# dDBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5j
# cmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEB
# CwUAA4ICAQBlKq3xHCcEua5gQezRCESeY0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZ
# D9gBq9fNaNmFj6Eh8/YmRDfxT7C0k8FUFqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/
# ML9lFfim8/9yJmZSe2F8AQ/UdKFOtj7YMTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu
# +WUqW4daIqToXFE/JQ/EABgfZXLWU0ziTN6R3ygQBHMUBaB5bdrPbF6MRYs03h4o
# bEMnxYOX8VBRKe1uNnzQVTeLni2nHkX/QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2h
# ECZpqyU1d0IbX6Wq8/gVutDojBIFeRlqAcuEVT0cKsb+zJNEsuEB7O7/cuvTQasn
# M9AWcIQfVjnzrvwiCZ85EE8LUkqRhoS3Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol
# /DJgddJ35XTxfUlQ+8Hggt8l2Yv7roancJIFcbojBcxlRcGG0LIhp6GvReQGgMgY
# xQbV1S3CrWqZzBt1R9xJgKf47CdxVRd/ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3oc
# CVccAvlKV9jEnstrniLvUxxVZE/rptb7IRE2lskKPIJgbaP5t2nGj/ULLi49xTcB
# ZU8atufk+EMF/cWuiC7POGT75qaL6vdCvHlshtjdNXOCIUjsarfNZzCCB20wggVV
# oAMCAQICEAnI7Fw0fQcgWcyoNeinb/gwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENB
# MTAeFw0yMzAzMjkwMDAwMDBaFw0yNjA2MjIyMzU5NTlaMHUxCzAJBgNVBAYTAkFV
# MRgwFgYDVQQIEw9OZXcgU291dGggV2FsZXMxFDASBgNVBAcTC0NoZXJyeWJyb29r
# MRowGAYDVQQKExFEYXJyZW4gSiBSb2JpbnNvbjEaMBgGA1UEAxMRRGFycmVuIEog
# Um9iaW5zb24wggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDHrKfntVGe
# XaDp6S/nqZuiKuhmIqivGTXM9VwXuzO3gV8FcuLWD+QciGujTkWBLHpVViPV5jtT
# PnD0uo0TK6WW/cbVB/jaSmTvnkrYYEwLZxDtXVmgCumOwB/2VY5oDk1mVwVYm4wB
# PyUCiH2cseB5uRTh+oat27JQPkVEKaNzUMTb9gLs3JCkMG1uwKFyDbnY9HbmAog2
# LIZ//Zh884C9FaTWEaZoBGu1loHNSR9e1fkmJWn+qjFqWKFrjg8Lg5bUh9qee6gC
# Nv+Ceq1GBL57O0GfbICFHRpVK+fen6dGOI7sqclRhO0a9GvD7Qci1lLqcle2eZCj
# 6/zEY3q1wJgZ3+gHYSN5GOho89+en2ZDwOPVLgiFxYMk2U/OAKOipcPtEaie9CQ7
# eOPVJMu4XWvofIdj4lHX+610Gplee5mOufpRwJnOPlIE7lrJ6cJ07jZZG2cUZwsN
# g/lt6raNmgYQ3m3Iimc4r34gFpVn03B7QqcveoDOS/jgeOXsw6VOigB9YcEUozkV
# JVucqBU11Gz1AUX5VNztm2dMHQCXslGGh1gGsjaMhX7ina5gi7SMe9ujtOnc/SoP
# nCX/tWXSeynFL2YEdnfBdfRVeRtQlTJzs4TGUdnZyHieYdBIHDijR5d4TChXVUce
# JYVvLXK0EDeGU9hIBnyPXwXNItxl0xQNMQIDAQABo4ICAzCCAf8wHwYDVR0jBBgw
# FoAUaDfg67Y7+F8Rhvv+YXsIiGX0TkIwHQYDVR0OBBYEFAUxVql07mJzafndN3rN
# ijPSXRlIMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzCBtQYD
# VR0fBIGtMIGqMFOgUaBPhk1odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNybDBT
# oFGgT4ZNaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# Q29kZVNpZ25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcmwwPgYDVR0gBDcwNTAz
# BgZngQwBBAEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5jb20v
# Q1BTMIGUBggrBgEFBQcBAQSBhzCBhDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3Au
# ZGlnaWNlcnQuY29tMFwGCCsGAQUFBzAChlBodHRwOi8vY2FjZXJ0cy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQy
# MDIxQ0ExLmNydDAJBgNVHRMEAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBYQAlozzK3
# Gn8A32eZnv51K5L+MmICIud+XHXTwJv9rMBg07s0lQVRyDAafC1i5s1zwNRm8QTp
# gOC/L7w4IxKUBfSPT4eTDWIGIYNMUqQCKffygKHODkJ8JckRjzfgo2smONMcU8+P
# 4R6IVoOK5yTCLlRI5DLSpzHU26Z6lPOcO/AEJXw+/b/4FkNnS9U959fBzhI07fFU
# rq8ZBIUOSN0h/Aq/WIVL/eDm1iFGzilLeUhu5v3fstpn5CkUjpkZbi0qGCz1m8d+
# aQK7GJGj6Y3+WJeY4iT2NxkMxFP0kVVtK68AwG7SkjdIClrWcYozw27PGkFGAoox
# X43ujlhheEZ5j0kIdBX/AMsz0HMfS40P/Fu4FBC7BOiBblz+W49ouoHi8uuS0XuO
# kGZWA6v2zGs1KGUE5Y3v4bOqZDi+H9Sr+7WyWZjBDVVVESTZng0Xo7zZYh2mhhAL
# /4hdGaO6ar4+MAgghht4/7DUeVkkWJ8X+cUOK/YvYGapOMo8JPwyQltq5ijQlKMT
# SGVodhCJTEg88NwzCpNspWXYmPywIuRpmwshi7erE8/yBNcNTWMK6f8+r+CPdZQ4
# HV4Pn05IYcbeO4VpozDg92WFUhc0JoPGpdYkP/ukWCoH7MMOuLSJMvCTjmV/97LP
# 7ocSlIzycWCZDsEMFMqAGM43LvwBOwctKzGCBlkwggZVAgEBMH0waTELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENB
# MQIQCcjsXDR9ByBZzKg16Kdv+DANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3
# AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDYthSPpQxA
# E3Acr3STgcFfsusQ+5ncj7wq+T45wWXR9TANBgkqhkiG9w0BAQEFAASCAgBCu6Ef
# rTa0f1qZKGdKCuw6ioFHXawVws7EhSiNRJTzHfkzey44cuyyQCtv71MTP1hHIBWM
# CeHZT3k+GzJPXj+r+89Xz4Ji4MoqOgIqEyTnYuuOZRlhkk7HH3i0rnii8cjnN05v
# 4TsADKFTqK/wjO7D5/JT6w1RXUI0b2Jbnt8+Ra6kfKfUiUrYpTkGYGRrOv+BXDGn
# vZQIsq3m5MsDG07z5v1OX8q342RGVYCjhSi64GFckRa7RNIMgUvGr46kPXpppKAG
# ruRQSqUyf7oYD0/Ds+g2Cf7VD38nIPCaX29BPUV2fT0PhBL8ez/8l2bNHwCW3ZO5
# V06EYysSFwvDu/m6PRCmGpmeIFucdTT052JfdCRqirdrWiCdr5dXCs8L1TXGEj3W
# b/2EbuZp1N1fF553p9MQNBAaw650qi1wh3oIcUJbLoeSmQpZUG+Ro1WSx/kWbbqG
# KPFKerRzfuCa2BF5w49TuJDeMFCIfBjlfE+DkA+hHYEgjtbEjSVVQwZF4krGEvYV
# wtTr0fikHC4WHkNqQlCvCaVIwtkYp/Gh3wGLw0TK1wCS4s3Bl5HWTKRLNmnXeQe4
# iFOu6eKPa4aqGLjXuoet8doRr3pHgVc3V39p1dc+9+/6rrtSV5XZeIDRB/1q2lxJ
# snnlTWjnr/IkzXd8g/olugMTQTBro9kUtAwwSKGCAyYwggMiBgkqhkiG9w0BCQYx
# ggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcg
# UlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZI
# AWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJ
# BTEPFw0yNTEyMDkwMTEyNDhaMC8GCSqGSIb3DQEJBDEiBCBuKfUm3ZkqrMTjoJJ6
# 88zfm6vpQlLHjkoHT7/2zHB9GDANBgkqhkiG9w0BAQEFAASCAgBrWw+moghuUYKY
# tAPr+OIUyXPYZqTvBh0uwOFiGUfxwO3bPNyLpP6UsJCriw7TzcuHeMyEP2dWguNr
# DWems3b5jL4V/nR36QechUevfR43HDXYu67TXFrM+MaNsP+bhjCQ7HopKNNMvcNr
# 5IMecb1mGReCzeh0Gek7uaIzqfP30+YZadlNN/AurSUHTTbAlWOkgeqRvpOa6pjC
# s8mET3T6/c2ICsEEoAyT4AuBIYnMm23NK8Y/TrUE1VS42JHSSHDeFrrAtnMCJC9Z
# AYNOGQ0UzDulozTKOZZyksYQrZyZrBMQVDGTmEKwlRxiZggQPJGGccJfyTw04EDE
# IQR5bDeMyc1G3ie4hHuCX+YZklZbwW1JotIhlSgbCFYYfOLbzULKNmG4RrI2jbyA
# 2ljbqXJQCBOIP/foARLRqcYQY7enmaCLvKfhYzvGQlPcbd5KuCJjZUoPsZWbRj9v
# fDR9jK7pZzCAGBMHbZzySKnI1JZym2Q4cN2GU6FWkyNL3PiAQ8yJqD23XCu0TViZ
# ELTseggyW7u7HUQ5qPHho8b6iocFv+BLcLaMN+xEynJhQvk+W2CdmAlN8OtjrtFt
# z9cE0hC+5jpO55vEy4kdmQtgWHzVNT/mrSQkQxJUZkeMGzH9twD6DFxS2Zb7lkBP
# r/26yu4y6c+vDNZ2QyEnmM/ZJFEPkA==
# SIG # End signature block
