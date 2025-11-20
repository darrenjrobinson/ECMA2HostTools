function Get-ECMA2ConnectorSecret {
    <#
    .SYNOPSIS
        Decrypts encrypted parameters and secret tokens from ECMA2 connectors.

    .DESCRIPTION
        Decrypts encrypted values from ECMA2Host connectors. This requires running
        as the same user account that the ECMA2Host service uses, on the same machine
        where the values were encrypted, as they use DPAPI (Data Protection API).

    .PARAMETER Name
        The name of the connector to decrypt secrets for.

    .PARAMETER ConfigurationPath
        Path to the Configuration.xml file. Defaults to the standard ECMA2Host location.

    .PARAMETER IncludeSecretToken
        Include the connector's SecretToken in the output (used for API authentication).

    .PARAMETER AsNetworkService
        Run the decryption in the context of the Network Service account (the default
        ECMA2Host service account). This is required if the encryption was done with
        CurrentUser scope. Requires Administrator privileges.

    .EXAMPLE
        Get-ECMA2ConnectorSecret -Name "APIConnector"
        Decrypts all encrypted parameters for the APIConnector connector.

    .EXAMPLE
        Get-ECMA2ConnectorSecret -Name "SQLConnector" -IncludeSecretToken
        Decrypts parameters and includes the API secret token.

    .EXAMPLE
        Get-ECMA2ConnectorSecret -Name "SQLConnector" -AsNetworkService -IncludeSecretToken
        Decrypts as Network Service account (requires running PowerShell as Administrator).

    .NOTES
        Must run on the same machine where encryption occurred.
        If decryption fails, try -AsNetworkService switch to run as the service account.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter()]
        [string]$ConfigurationPath = 'C:\Program Files\Microsoft ECMA2Host\Service\Configuration\Configuration.xml',

        [Parameter()]
        [switch]$IncludeSecretToken,

        [Parameter()]
        [switch]$AsNetworkService
    )

    begin {
        # Check PowerShell version - BinaryFormatter is disabled in PS 7+
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Write-Warning "BinaryFormatter is disabled in PowerShell 7+. Attempting to use Windows PowerShell 5.1 for decryption..."
            $script:UseWindowsPowerShell = $true
        }
        else {
            Write-Verbose "Running in Windows PowerShell $($PSVersionTable.PSVersion), BinaryFormatter available"
            $script:UseWindowsPowerShell = $false
            
            # Load the ECMA2Host encryption assembly
            $ecmaHostPath = 'C:\Program Files\Microsoft ECMA2Host\Service'
            $encryptedDll = Join-Path $ecmaHostPath 'Microsoft.ECMA2Host.Encrypted.dll'
            
            if (-not (Test-Path $encryptedDll)) {
                throw "Microsoft.ECMA2Host.Encrypted.dll not found at: $encryptedDll"
            }

            try {
                # Load the assembly and get EncryptTools type
                $assembly = [System.Reflection.Assembly]::LoadFrom($encryptedDll)
                $script:EncryptToolsType = $assembly.GetType('Microsoft.ECMA2Host.Encrypted.EncryptTools')
                Write-Verbose "Loaded ECMA2Host encryption assembly"
            }
            catch {
                throw "Failed to load encryption assembly: $_"
            }
        }
    }

    process {
        # If running in PS7+, delegate to Windows PowerShell 5.1
        if ($script:UseWindowsPowerShell) {
            try {
                Write-Verbose "Delegating decryption to Windows PowerShell 5.1"
                
                # Build the command to run in Windows PowerShell
                $modulePath = Split-Path -Parent $PSScriptRoot
                $manifestPath = Join-Path $modulePath 'ECMA2HostTools.psd1'
                
                # Build parameter string
                $paramString = "-Name '$Name'"
                if ($PSBoundParameters.ContainsKey('ConfigurationPath')) {
                    $paramString += " -ConfigurationPath '$ConfigurationPath'"
                }
                if ($IncludeSecretToken) {
                    $paramString += " -IncludeSecretToken"
                }
                
                $ps51Command = @"
Import-Module '$manifestPath' -Force -WarningAction SilentlyContinue
`$result = Get-ECMA2ConnectorSecret $paramString
`$result | ConvertTo-Json -Depth 10 -Compress
"@
                
                $result = powershell.exe -NoProfile -NonInteractive -Command $ps51Command 2>&1
                
                # Filter out error messages to get only JSON
                $jsonOutput = $result | Where-Object { $_ -is [string] -and $_ -match '^\{' }
                
                if (-not $jsonOutput) {
                    $errorMessages = $result | Where-Object { $_ -isnot [string] -or $_ -notmatch '^\{' }
                    throw "No JSON output received. Errors: $($errorMessages -join '; ')"
                }
                
                $returnObject = ($jsonOutput | ConvertFrom-Json)
                
                # Convert EncryptedParameters back to hashtable if it's a PSCustomObject
                # This ensures consistent display and access patterns
                if ($returnObject.EncryptedParameters -and $returnObject.EncryptedParameters -isnot [hashtable]) {
                    $hashtable = @{}
                    $returnObject.EncryptedParameters.PSObject.Properties | ForEach-Object {
                        # Keep the PSCustomObject as-is for better property access
                        $hashtable[$_.Name] = $_.Value
                    }
                    # Replace with hashtable
                    $returnObject | Add-Member -MemberType NoteProperty -Name 'EncryptedParameters' -Value $hashtable -Force
                }
                
                # Add a formatted display property for better readability
                $returnObject | Add-Member -MemberType ScriptProperty -Name 'DecryptedSecrets' -Value {
                    $this.EncryptedParameters
                } -Force
                
                # Re-add the typename
                $returnObject.PSObject.TypeNames.Insert(0, 'ECMA2Host.ConnectorSecret')
                
                return $returnObject
            }
            catch {
                Write-Error "Failed to decrypt using Windows PowerShell 5.1: $_"
                Write-Warning "To decrypt secrets, either:"
                Write-Warning "1. Run this cmdlet in Windows PowerShell 5.1: powershell.exe"
                Write-Warning "2. Use the ECMA2Host configuration UI to view secrets"
                return
            }
        }

        # If AsNetworkService is specified, use PsExec or scheduled task to run as Network Service
        if ($AsNetworkService) {
            Write-Verbose "Attempting to run decryption as Network Service account"
            
            # Create a script block that will run as Network Service
            $scriptPath = Join-Path $env:TEMP "Decrypt-ECMA2Secret-$(Get-Random).ps1"
            
            $scriptContent = @"
Import-Module '$PSScriptRoot\..\ECMA2HostTools.psd1'
Get-ECMA2ConnectorSecret -Name '$Name' -ConfigurationPath '$ConfigurationPath' $(if($IncludeSecretToken){'-IncludeSecretToken'}) | ConvertTo-Json -Depth 10
"@
            Set-Content -Path $scriptPath -Value $scriptContent
            
            try {
                # Use scheduled task to run as Network Service
                $taskName = "ECMA2-Decrypt-$(Get-Random)"
                $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
                $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\NETWORK SERVICE" -LogonType ServiceAccount
                
                Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force | Out-Null
                
                Write-Verbose "Running decryption as Network Service via scheduled task"
                $task = Start-ScheduledTask -TaskName $taskName -PassThru
                
                # Wait for completion
                $timeout = 30
                $timer = [Diagnostics.Stopwatch]::StartNew()
                while ($task.State -ne 'Ready' -and $timer.Elapsed.TotalSeconds -lt $timeout) {
                    Start-Sleep -Milliseconds 500
                    $task = Get-ScheduledTask -TaskName $taskName
                }
                
                # Get the output from the last run
                $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
                
                # Read output - note: scheduled tasks don't capture output easily
                # Better approach: have the script write to a temp file
                Write-Warning "Scheduled task completed. Output capture for scheduled tasks is limited."
                Write-Warning "Consider running PowerShell as Administrator and using -Verbose for more details."
                
                return [PSCustomObject]@{
                    Name = $Name
                    Note = "Decryption attempted as Network Service. Check Windows Event Log for details."
                }
            }
            finally {
                # Cleanup
                if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                }
                if (Test-Path $scriptPath) {
                    Remove-Item $scriptPath -Force
                }
            }
            
            return
        }

        try {
            if (-not (Test-Path $ConfigurationPath)) {
                throw "Configuration file not found at: $ConfigurationPath"
            }

            Write-Verbose "Loading configuration from $ConfigurationPath"
            [xml]$config = Get-Content -Path $ConfigurationPath -Raw

            # Find the connector
            $connector = $config.Configuration.Connectors.Connector | Where-Object {
                $_.ECMAConfig.ProfileName -eq $Name
            }

            if (-not $connector) {
                throw "Connector '$Name' not found in configuration"
            }

            $result = [PSCustomObject]@{
                Name = $Name
                EncryptedParameters = @{}
                SecretToken = $null
                ComputerName = $env:COMPUTERNAME
            }
            
            # Add typename for potential future formatting
            $result.PSObject.TypeNames.Insert(0, 'ECMA2Host.ConnectorSecret')

            # Decrypt encrypted parameters
            Write-Verbose "Processing connector parameters"
            
            # Get parameters from the correct location (ConnectorConfig.Parameters.Parameter)
            $paramList = $connector.ConnectorConfig.Parameters.Parameter
            if ($paramList -and $paramList -isnot [System.Array]) {
                $paramList = @($paramList)
            }
            
            foreach ($param in $paramList) {
                if ($param.Type -eq 'EncryptedString' -and $param.Encrypted -eq 'true' -and $param.Value) {
                    Write-Verbose "Decrypting parameter: $($param.Name)"
                    
                    try {
                        # Use EncryptTools.GetDecryptedSecureString
                        $getDecryptedMethod = $script:EncryptToolsType.GetMethod('GetDecryptedSecureString', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
                        $secureString = $getDecryptedMethod.Invoke($null, @($param.Value))
                        
                        # Convert SecureString to plain text
                        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
                        $decryptedValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                        
                        $result.EncryptedParameters[$param.Name] = [PSCustomObject]@{
                            Name = $param.Name
                            Value = $decryptedValue
                            Use = $param.Use
                        }
                    }
                    catch {
                        Write-Warning "Failed to decrypt parameter '$($param.Name)': $_"
                        $result.EncryptedParameters[$param.Name] = [PSCustomObject]@{
                            Name = $param.Name
                            Value = "[DECRYPTION FAILED]"
                            Error = $_.Exception.Message
                        }
                    }
                }
            }

            # Decrypt SecretToken if requested
            if ($IncludeSecretToken -and $connector.ECMAConfig.SecretToken) {
                Write-Verbose "Decrypting SecretToken"
                
                try {
                    # Use EncryptTools.GetDecryptedSecureString
                    $getDecryptedMethod = $script:EncryptToolsType.GetMethod('GetDecryptedSecureString', [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static)
                    $secureString = $getDecryptedMethod.Invoke($null, @($connector.ECMAConfig.SecretToken))
                    
                    # Convert SecureString to plain text
                    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
                    $result.SecretToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                }
                catch {
                    Write-Warning "Failed to decrypt SecretToken: $_"
                    $result.SecretToken = "[DECRYPTION FAILED: $($_.Exception.Message)]"
                }
            }

            return $result
        }
        catch {
            Write-Error "Failed to decrypt secrets for connector '$Name': $_"
        }
    }
}
