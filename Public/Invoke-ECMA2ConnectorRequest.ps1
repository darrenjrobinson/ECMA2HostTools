function Invoke-ECMA2ConnectorRequest {
    <#
    .SYNOPSIS
        Sends a SCIM request (create/update/delete) to an ECMA2 connector.

    .DESCRIPTION
        Posts a SCIM request to the ECMA2Host service to create, update, or delete 
        objects in a connector, similar to how Microsoft Entra provisioning service 
        sends provisioning requests to connectors.
        
        Supports POST (create), PUT (update), PATCH (partial update), and DELETE operations.
        REQUIRES authentication via secret token - all ECMA2Host connectors enforce 
        Bearer token authentication for SCIM operations.

    .PARAMETER ConnectorName
        The name of the connector to send the request to.

    .PARAMETER SecretToken
        The secret token for authenticating to the connector (SecureString or String).
        REQUIRED for all operations. Can be obtained from Get-ECMA2ConnectorSecret.
        All ECMA2Host connectors require authentication via Bearer token.

    .PARAMETER Port
        The HTTPS port number where ECMA2Host is listening. Defaults to 8585.

    .PARAMETER Hostname
        The hostname of the ECMA2Host server. Defaults to current computer.

    .PARAMETER ObjectTypePath
        The object type collection to target. Defaults to "Users".

    .PARAMETER Method
        The HTTP method to use. Valid values: POST (create), PUT (update), PATCH (partial update), DELETE.
        Defaults to POST.

    .PARAMETER Body
        The request body as a hashtable or PSCustomObject. Will be converted to JSON.
        For POST/PUT/PATCH operations, this typically includes SCIM schemas and attributes.

    .PARAMETER RequestIdentifier
        Optional request identifier (GUID). If not provided, a new GUID will be generated.
        This is sent in the ADSCIMVersion header for request tracking.

    .PARAMETER ActivityId
        Optional activity identifier (GUID). If not provided, a new GUID will be generated.
        This is sent in the ADSCIMVersion header for activity tracking.

    .PARAMETER ObjectId
        The object ID to target for PUT, PATCH, or DELETE operations.
        Not used for POST (create) operations.

    .PARAMETER SkipCertificateCheck
        Skip SSL certificate validation (for testing environments).

    .PARAMETER ShowDetails
        Show verbose request/response details including headers and body.

    .PARAMETER InputObject
        Connector object from Get-ECMA2Connector (via pipeline).

    .EXAMPLE
        # Create a new user in a connector
        $body = @{
            schemas = @(
                "urn:ietf:params:scim:schemas:core:2.0:User",
                "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
            )
            active = $true
            meta = @{
                resourceType = "User"
            }
            "urn:ietf:params:scim:schemas:extension:ECMA2Host:2.0:User" = @{
                id = "S-1-5-21-1234567890-1234567890-1234567890-12345"
                displayName = "John Smith"
                emailPrimary = "john.smith@example.com"
                externalId = "12345"
                userName = "jsmith"
                userType = "Employee"
            }
        }
        
        $secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
        Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret -Body $body -ShowDetails

    .EXAMPLE
        # Update an existing user (PUT)
        $body = @{
            schemas = @("urn:ietf:params:scim:schemas:core:2.0:User")
            active = $false
        }
        
        $secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
        Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
            -Method PUT -ObjectId "12345" -Body $body

    .EXAMPLE
        # Partial update (PATCH)
        $body = @{
            schemas = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
            Operations = @(
                @{
                    op = "replace"
                    path = "active"
                    value = $false
                }
            )
        }
        
        $secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
        Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
            -Method PATCH -ObjectId "12345" -Body $body

    .EXAMPLE
        # Delete a user
        $secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
        Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
            -Method DELETE -ObjectId "12345"

    .EXAMPLE
        # Pipeline from Get-ECMA2Connector
        $secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
        Get-ECMA2Connector -Name "APIConnector" |
            Invoke-ECMA2ConnectorRequest -SecretToken $secret -Body $body
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ParameterSetName = 'Direct', Mandatory)]
        [string]$ConnectorName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $SecretToken,

        [Parameter()]
        [int]$Port = 8585,

        [Parameter()]
        [string]$Hostname,

        [Parameter()]
        [string]$ObjectTypePath = "Users",

        [Parameter()]
        [ValidateSet('POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'POST',

        [Parameter(Mandatory, ParameterSetName = 'Direct')]
        [Parameter(Mandatory, ParameterSetName = 'Pipeline')]
        [AllowNull()]
        [object]$Body,

        [Parameter()]
        [guid]$RequestIdentifier,

        [Parameter()]
        [guid]$ActivityId,

        [Parameter()]
        [string]$ObjectId,

        [Parameter()]
        [switch]$SkipCertificateCheck,

        [Parameter()]
        [switch]$ShowDetails,

        [Parameter(ParameterSetName = 'Pipeline', ValueFromPipeline)]
        [PSTypeName('ECMA2Host.Connector')]
        [object]$InputObject
    )

    begin {
        Write-Verbose "Starting Invoke-ECMA2ConnectorRequest operation"
        
        # Set hostname
        if ([string]::IsNullOrEmpty($Hostname)) {
            $Hostname = [System.Net.Dns]::GetHostName()
        }

        # Handle SSL certificate validation
        if ($SkipCertificateCheck) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            Write-Warning "SSL certificate validation has been disabled for this session"
        }

        # Generate identifiers if not provided
        if (-not $RequestIdentifier) {
            $RequestIdentifier = [guid]::NewGuid()
        }
        if (-not $ActivityId) {
            $ActivityId = [guid]::NewGuid()
        }

        Write-Verbose "Request Identifier: $RequestIdentifier"
        Write-Verbose "Activity ID: $ActivityId"
    }

    process {
        try {
            # Get connector name from pipeline if provided
            $targetConnectorName = if ($InputObject) {
                $InputObject.Name
            } else {
                $ConnectorName
            }

            if ([string]::IsNullOrEmpty($targetConnectorName)) {
                throw "ConnectorName is required. Provide it as a parameter or via pipeline from Get-ECMA2Connector."
            }

            Write-Verbose "Sending $Method request to connector: $targetConnectorName"

            # Validate ObjectId for non-POST operations
            if ($Method -ne 'POST' -and [string]::IsNullOrEmpty($ObjectId)) {
                throw "ObjectId is required for $Method operations"
            }

            # Validate Body for POST/PUT/PATCH
            if ($Method -in @('POST', 'PUT', 'PATCH') -and $null -eq $Body) {
                throw "Body is required for $Method operations"
            }

            # Build URI
            $baseuri = "https://$Hostname`:$Port/ecma2host_$targetConnectorName/scim/$ObjectTypePath"
            
            if ($Method -ne 'POST') {
                # Append ObjectId for PUT, PATCH, DELETE
                $uri = "$baseuri/$ObjectId"
            } else {
                $uri = $baseuri
            }

            Write-Verbose "Request URI: $uri"

            # Setup headers
            $headers = @{
                'Content-Type' = 'application/json'
                'ADSCIMVersion' = "Date:$([DateTime]::UtcNow.ToString('o')), ActivityId:$ActivityId"
            }

            # Convert SecretToken to string (handle both SecureString and plain string)
            if ($SecretToken -is [SecureString]) {
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecretToken)
                $BearerToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            } elseif ($SecretToken -is [string]) {
                $BearerToken = $SecretToken
            } else {
                throw "SecretToken must be either a SecureString or a String (GUID)"
            }

            if ([string]::IsNullOrEmpty($BearerToken)) {
                throw "SecretToken cannot be empty. All ECMA2Host connectors require authentication. Use Get-ECMA2ConnectorSecret -IncludeSecretToken to retrieve the token."
            }

            $headers["Authorization"] = "Bearer $BearerToken"
            Write-Verbose "Authentication: Bearer token configured"

            # Convert body to JSON if needed
            $jsonBody = $null
            if ($null -ne $Body -and $Method -ne 'DELETE') {
                if ($Body -is [string]) {
                    $jsonBody = $Body
                } else {
                    $jsonBody = $Body | ConvertTo-Json -Depth 10
                }
            }

            # Show details if requested
            if ($ShowDetails) {
                Write-Host "`n=== Request Details ===" -ForegroundColor Cyan
                Write-Host "Method: $Method" -ForegroundColor Yellow
                Write-Host "URI: $uri" -ForegroundColor Yellow
                Write-Host "Request Identifier: $RequestIdentifier" -ForegroundColor Yellow
                Write-Host "`nHeaders:" -ForegroundColor Yellow
                $headers.GetEnumerator() | ForEach-Object {
                    if ($_.Key -eq "Authorization") {
                        Write-Host "  $($_.Key): Bearer [REDACTED]" -ForegroundColor Gray
                    } else {
                        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
                    }
                }
                
                if ($null -ne $jsonBody) {
                    Write-Host "`nContent:" -ForegroundColor Yellow
                    Write-Host $jsonBody -ForegroundColor Gray
                }
                Write-Host ""
            }

            # WhatIf support
            $operationDescription = switch ($Method) {
                'POST'   { "Creating new object in connector '$targetConnectorName'" }
                'PUT'    { "Updating object '$ObjectId' in connector '$targetConnectorName'" }
                'PATCH'  { "Partially updating object '$ObjectId' in connector '$targetConnectorName'" }
                'DELETE' { "Deleting object '$ObjectId' from connector '$targetConnectorName'" }
            }

            if ($PSCmdlet.ShouldProcess($targetConnectorName, $operationDescription)) {
                # Make the request
                $requestParams = @{
                    Uri = $uri
                    Method = $Method
                    Headers = $headers
                    ErrorAction = 'Stop'
                }

                if ($null -ne $jsonBody) {
                    $requestParams['Body'] = $jsonBody
                }

                $resp = Invoke-WebRequest @requestParams

                if ($ShowDetails) {
                    Write-Host "=== Response ===" -ForegroundColor Cyan
                    Write-Host "Status Code: $($resp.StatusCode) $($resp.StatusDescription)" -ForegroundColor Green
                    Write-Host "`nResponse Headers:" -ForegroundColor Yellow
                    $resp.Headers.GetEnumerator() | ForEach-Object {
                        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
                    }
                    Write-Host ""
                }

                # Parse response if there is content
                $responseContent = $resp.Content
                if (-not [string]::IsNullOrWhiteSpace($responseContent)) {
                    if ($responseContent -is [byte[]]) {
                        $responseContent = [System.Text.Encoding]::UTF8.GetString($responseContent)
                    }
                    elseif ($responseContent -is [object[]]) {
                        $responseContent = $responseContent -join ''
                    }
                    
                    $responseObj = $responseContent | ConvertFrom-Json

                    if ($ShowDetails -and $null -ne $responseObj) {
                        Write-Host "Response Content:" -ForegroundColor Yellow
                        Write-Host ($responseObj | ConvertTo-Json -Depth 10) -ForegroundColor Gray
                        Write-Host ""
                    }

                    # Return structured response
                    [PSCustomObject]@{
                        PSTypeName = 'ECMA2Host.ConnectorRequestResult'
                        ConnectorName = $targetConnectorName
                        Method = $Method
                        StatusCode = $resp.StatusCode
                        StatusDescription = $resp.StatusDescription
                        RequestIdentifier = $RequestIdentifier
                        ActivityId = $ActivityId
                        ObjectId = if ($Method -eq 'POST') { $responseObj.id } else { $ObjectId }
                        Response = $responseObj
                        Success = $true
                    }
                } else {
                    # No content response (e.g., DELETE)
                    [PSCustomObject]@{
                        PSTypeName = 'ECMA2Host.ConnectorRequestResult'
                        ConnectorName = $targetConnectorName
                        Method = $Method
                        StatusCode = $resp.StatusCode
                        StatusDescription = $resp.StatusDescription
                        RequestIdentifier = $RequestIdentifier
                        ActivityId = $ActivityId
                        ObjectId = $ObjectId
                        Response = $null
                        Success = $true
                    }
                }

                Write-Verbose "$Method request completed successfully (Status: $($resp.StatusCode))"
            }
        }
        catch {
            $innerMsg = $_.Exception.InnerException.Message

            if ($null -ne $innerMsg) {
                if ($innerMsg -eq "The remote certificate is invalid according to the validation procedure.") {
                    Write-Error "Could not validate TLS certificate. Use -SkipCertificateCheck for testing environments."
                    throw
                }
                if ($innerMsg.StartsWith("No connection could be made")) {
                    Write-Error "Could not connect to ECMA2Host service. Ensure the service is running on $Hostname`:$Port"
                    throw
                }
            }

            $StatusCode = $_.Exception.Response.StatusCode.value__
            if ($null -eq $StatusCode) {
                Write-Error $innerMsg
                throw
            } 
            elseif ($StatusCode -eq 503) {
                Write-Error "Service unavailable (503). The Microsoft ECMA2Host service may be paused, starting, or stopping."
                Write-Error "Common causes: Configuration Wizard is open, service is transitioning states, or connector '$targetConnectorName' does not exist."
                Write-Warning "Check service status with: Get-Service 'Microsoft ECMA2Host' | Select-Object Status"
                throw
            } 
            elseif ($StatusCode -eq 401) {
                Write-Error "Unauthorized (401). Authentication failed - the secret token may be incorrect, expired, or invalid."
                Write-Error "Verify the token with: Get-ECMA2ConnectorSecret -Name '$targetConnectorName' -IncludeSecretToken"
                throw
            } 
            elseif ($StatusCode -eq 400) {
                Write-Error "Bad request (400). Check your request body and SCIM format."
                
                # Try to get error details from response
                try {
                    $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($errorResponse) {
                        Write-Error "Server error details: $($errorResponse | ConvertTo-Json -Compress)"
                    }
                }
                catch {
                    Write-Verbose "Could not parse error details"
                }
                
                throw
            } 
            elseif ($StatusCode -eq 404) {
                Write-Error "Not found (404). The object '$ObjectId' may not exist in connector '$targetConnectorName'."
                throw
            }
            elseif ($StatusCode -eq 409) {
                Write-Error "Conflict (409). The object may already exist or there is a uniqueness constraint violation."
                throw
            }
            elseif ($StatusCode -eq 500) {
                Write-Error "Internal server error (500). This may indicate a mapping exception or data type issue in the connector."
                
                # Try to parse mapping exception details
                try {
                    $fullErrorText = $_.ToString()
                    if ($fullErrorText -match '\{\s*"ExceptionMessage"[^}]*"ExceptionType"[^}]*\}') {
                        $errorContent = $matches[0]
                        $errorObj = $errorContent | ConvertFrom-Json -ErrorAction SilentlyContinue
                        if ($errorObj -and $errorObj.ExceptionType -eq "MappingException") {
                            Write-Warning "Mapping Exception: $($errorObj.ExceptionMessage)"
                            Write-Warning "Check connector export/import script for data type issues or null values in required fields."
                        }
                    }
                }
                catch {
                    Write-Verbose "Could not parse error details: $($_.Exception.Message)"
                }
                
                throw
            } 
            else {
                Write-Error "HTTP Status Code ${StatusCode}: $($_.Exception.Message)"
                throw
            }
        }
    }

    end {
        # Restore certificate validation if it was disabled
        if ($SkipCertificateCheck) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
            Write-Verbose "SSL certificate validation restored"
        }
        
        Write-Verbose "Invoke-ECMA2ConnectorRequest operation completed"
    }
}
