function Start-ECMA2Host {
    <#
    .SYNOPSIS
        Starts the ECMA2Host service.

    .DESCRIPTION
        Starts the ECMA2Host service on the local or remote computer. This service
        hosts ECMA2 connectors for Microsoft Identity Manager synchronization.

    .PARAMETER ComputerName
        The name of the computer where ECMA2Host service should be started.
        Defaults to the local computer.

    .PARAMETER Credential
        Credentials to use when connecting to a remote computer.

    .EXAMPLE
        Start-ECMA2Host
        Starts the ECMA2Host service on the local computer.

    .EXAMPLE
        Start-ECMA2Host -ComputerName "Server01" -Credential (Get-Credential)
        Starts the ECMA2Host service on Server01 using specified credentials.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [PSCredential]$Credential
    )

    begin {
        Write-Verbose "Starting ECMA2Host service operation"
    }

    process {
        try {
            # Check if running locally or remotely to determine which cmdlets to use
            $isLocal = ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq 'localhost' -or $ComputerName -eq '.')
            
            if ($PSCmdlet.ShouldProcess($ComputerName, "Start ECMA2Host service")) {
                Write-Verbose "Checking ECMA2Host service status on $ComputerName"
                
                # Get current service status
                if ($isLocal) {
                    $service = Get-Service -Name 'Microsoft ECMA2Host' -ErrorAction Stop
                }
                else {
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
                }
                
                # Determine if service is paused or stopped
                $currentStatus = if ($isLocal) { $service.Status } else { $cimService.State }
                
                if ($currentStatus -eq 'Running') {
                    Write-Verbose "ECMA2Host service is already running"
                    if ($isLocal) {
                        return $service
                    }
                    else {
                        return [PSCustomObject]@{
                            Name = $cimService.Name
                            Status = 'Running'
                            ComputerName = $ComputerName
                        }
                    }
                }
                elseif ($currentStatus -eq 'Paused') {
                    Write-Verbose "ECMA2Host service is paused, resuming on $ComputerName"
                    
                    if ($isLocal) {
                        # Try using sc.exe for better compatibility and clearer error messages
                        $result = & sc.exe continue "Microsoft ECMA2Host" 2>&1
                        if ($LASTEXITCODE -eq 5) {
                            throw "Access denied. You must run PowerShell as Administrator to resume the ECMA2Host service."
                        }
                        elseif ($LASTEXITCODE -ne 0) {
                            throw "Failed to resume service. sc.exe exit code: $LASTEXITCODE. Output: $result"
                        }
                    }
                    else {
                        # Use Invoke-CimMethod to resume the service
                        $result = Invoke-CimMethod -InputObject $cimService -MethodName ResumeService
                        if ($result.ReturnValue -ne 0) {
                            throw "Failed to resume service. Return code: $($result.ReturnValue)"
                        }
                    }
                }
                else {
                    Write-Verbose "Starting ECMA2Host service on $ComputerName"
                    
                    if ($isLocal) {
                        # Try using sc.exe for better compatibility and clearer error messages
                        $result = & sc.exe start "Microsoft ECMA2Host" 2>&1
                        if ($LASTEXITCODE -eq 5) {
                            throw "Access denied. You must run PowerShell as Administrator to start the ECMA2Host service."
                        }
                        elseif ($LASTEXITCODE -ne 0) {
                            throw "Failed to start service. sc.exe exit code: $LASTEXITCODE. Output: $result"
                        }
                    }
                    else {
                        # Use Invoke-CimMethod to start the service
                        $result = Invoke-CimMethod -InputObject $cimService -MethodName StartService
                        if ($result.ReturnValue -ne 0) {
                            throw "Failed to start service. Return code: $($result.ReturnValue)"
                        }
                    }
                }
                
                # Wait for service to be running
                $timeout = 30
                $timer = [Diagnostics.Stopwatch]::StartNew()
                
                do {
                    if ($isLocal) {
                        $service = Get-Service -Name 'Microsoft ECMA2Host'
                        if ($service.Status -eq 'Running') {
                            Write-Verbose "ECMA2Host service is now running"
                            return $service
                        }
                    }
                    else {
                        $cimService = Get-CimInstance @cimParams
                        if ($cimService.State -eq 'Running') {
                            Write-Verbose "ECMA2Host service is now running"
                            return [PSCustomObject]@{
                                Name = $cimService.Name
                                DisplayName = $cimService.DisplayName
                                Status = 'Running'
                                ComputerName = $ComputerName
                            }
                        }
                    }
                    Start-Sleep -Milliseconds 500
                } while ($timer.Elapsed.TotalSeconds -lt $timeout)

                Write-Warning "ECMA2Host service did not start within $timeout seconds"
            }
        }
        catch {
            Write-Error "Failed to start ECMA2Host service on $ComputerName : $_"
        }
    }

    end {
        Write-Verbose "Start-ECMA2Host operation completed"
    }
}
