function Stop-ECMA2Host {
    <#
    .SYNOPSIS
        Stops the ECMA2Host service.

    .DESCRIPTION
        Stops the ECMA2Host service on the local or remote computer. This will
        terminate all running connector operations.

    .PARAMETER ComputerName
        The name of the computer where ECMA2Host service should be stopped.
        Defaults to the local computer.

    .PARAMETER Credential
        Credentials to use when connecting to a remote computer.

    .PARAMETER Force
        Forces the service to stop even if it has dependent services.

    .EXAMPLE
        Stop-ECMA2Host
        Stops the ECMA2Host service on the local computer.

    .EXAMPLE
        Stop-ECMA2Host -ComputerName "Server01" -Force
        Forcefully stops the ECMA2Host service on Server01.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Stopping ECMA2Host service operation"
    }

    process {
        try {
            # Check if running locally or remotely to determine which cmdlets to use
            $isLocal = ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq 'localhost' -or $ComputerName -eq '.')
            
            if ($PSCmdlet.ShouldProcess($ComputerName, "Stop ECMA2Host service")) {
                Write-Verbose "Stopping ECMA2Host service on $ComputerName"
                
                if ($isLocal) {
                    # Try using sc.exe for better compatibility and clearer error messages
                    $result = & sc.exe stop "Microsoft ECMA2Host" 2>&1
                    if ($LASTEXITCODE -eq 5) {
                        throw "Access denied. You must run PowerShell as Administrator to stop the ECMA2Host service."
                    }
                    elseif ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1062) {  # 1062 = service not started
                        throw "Failed to stop service. sc.exe exit code: $LASTEXITCODE. Output: $result"
                    }
                }
                else {
                    # Use Get-CimInstance and Invoke-CimMethod for remote operations
                    $cimParams = @{
                        ClassName = 'Win32_Service'
                        Filter = "Name='Microsoft ECMA2Host'"
                        ComputerName = $ComputerName
                    }
                    if ($Credential) {
                        $cimParams['Credential'] = $Credential
                    }
                    
                    $cimService = Get-CimInstance @cimParams -ErrorAction Stop
                    
                    if (-not $cimService) {
                        throw "Service 'Microsoft ECMA2Host' not found on $ComputerName"
                    }
                    
                    # Stop the service using CIM method
                    $result = Invoke-CimMethod -InputObject $cimService -MethodName StopService
                    if ($result.ReturnValue -ne 0) {
                        throw "Failed to stop service. Return code: $($result.ReturnValue)"
                    }
                }
                
                # Wait for service to stop
                $timeout = 30
                $timer = [Diagnostics.Stopwatch]::StartNew()
                
                do {
                    if ($isLocal) {
                        $service = Get-Service -Name 'Microsoft ECMA2Host'
                        if ($service.Status -eq 'Stopped') {
                            Write-Verbose "ECMA2Host service stopped successfully"
                            return $service
                        }
                    }
                    else {
                        $cimService = Get-CimInstance @cimParams
                        if ($cimService.State -eq 'Stopped') {
                            Write-Verbose "ECMA2Host service stopped successfully"
                            return [PSCustomObject]@{
                                Name = $cimService.Name
                                DisplayName = $cimService.DisplayName
                                Status = 'Stopped'
                                ComputerName = $ComputerName
                            }
                        }
                    }
                    Start-Sleep -Milliseconds 500
                } while ($timer.Elapsed.TotalSeconds -lt $timeout)

                Write-Warning "ECMA2Host service did not stop within $timeout seconds"
            }
        }
        catch {
            Write-Error "Failed to stop ECMA2Host service on $ComputerName : $_"
        }
    }

    end {
        Write-Verbose "Stop-ECMA2Host operation completed"
    }
}
