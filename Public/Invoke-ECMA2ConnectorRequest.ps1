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
        # Get a specific object by ID
        $secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
        Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
            -Method GET -ObjectId "12345"

    .EXAMPLE
        # Query objects with a filter (replicates Entra SCIM queries)
        $secret = (Get-ECMA2ConnectorSecret -Name "CENet" -IncludeSecretToken).SecretToken
        Invoke-ECMA2ConnectorRequest -ConnectorName "CENet" -SecretToken $secret `
            -Method GET -FilterAttribute "urn:ietf:params:scim:schemas:extension:ECMA2Host:2.0:User:ceider" `
            -FilterValue "317366309" -ShowDetails

    .EXAMPLE
        # Query with custom filter
        $secret = (Get-ECMA2ConnectorSecret -Name "APIConnector" -IncludeSecretToken).SecretToken
        Invoke-ECMA2ConnectorRequest -ConnectorName "APIConnector" -SecretToken $secret `
            -Method GET -CustomFilter 'userName eq "jsmith"'

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
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'POST',

        [Parameter(ParameterSetName = 'Direct')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [AllowNull()]
        [object]$Body,

        [Parameter()]
        [guid]$RequestIdentifier,

        [Parameter()]
        [guid]$ActivityId,

        [Parameter()]
        [string]$ObjectId,

        [Parameter()]
        [string]$FilterAttribute,

        [Parameter()]
        [string]$FilterValue,

        [Parameter()]
        [string]$CustomFilter,

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

            # Validate ObjectId for PUT/PATCH/DELETE operations
            if ($Method -in @('PUT', 'PATCH', 'DELETE') -and [string]::IsNullOrEmpty($ObjectId)) {
                throw "ObjectId is required for $Method operations"
            }

            # Validate Body for POST/PUT/PATCH
            if ($Method -in @('POST', 'PUT', 'PATCH') -and $null -eq $Body) {
                throw "Body is required for $Method operations"
            }

            # Build URI
            $baseuri = "https://$Hostname`:$Port/ecma2host_$targetConnectorName/scim/$ObjectTypePath"
            
            if ($Method -in @('PUT', 'PATCH', 'DELETE')) {
                # Append ObjectId for PUT, PATCH, DELETE
                $uri = "$baseuri/$ObjectId"
            } elseif ($Method -eq 'GET' -and -not [string]::IsNullOrEmpty($ObjectId)) {
                # GET specific object by ID
                $uri = "$baseuri/$ObjectId"
            } elseif ($Method -eq 'GET') {
                # GET with optional filter
                $uri = $baseuri
                
                if ($PSBoundParameters.ContainsKey('FilterAttribute')) {
                    # Build filter expression using SCIM 'eq' operator
                    $filterExpression = "$FilterAttribute eq `"$FilterValue`""
                    $encodedFilter = [System.Web.HttpUtility]::UrlEncode($filterExpression)
                    $uri = "$uri`?filter=$encodedFilter"
                    Write-Verbose "Filter: $filterExpression"
                } elseif ($CustomFilter) {
                    # Use custom filter
                    $encodedFilter = [System.Web.HttpUtility]::UrlEncode($CustomFilter)
                    $uri = "$uri`?filter=$encodedFilter"
                    Write-Verbose "Custom Filter: $CustomFilter"
                }
            } else {
                $uri = $baseuri
            }

            Write-Verbose "Request URI: $uri"

            # Setup headers
            $headers = @{
                'ADSCIMVersion' = "Date:$([DateTime]::UtcNow.ToString('o')), ActivityId:$ActivityId"
            }
            
            # Add Content-Type for methods that send a body
            if ($Method -in @('POST', 'PUT', 'PATCH')) {
                $headers['Content-Type'] = 'application/json'
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
                'GET'    { if ($ObjectId) { "Retrieving object '$ObjectId' from connector '$targetConnectorName'" } else { "Querying objects from connector '$targetConnectorName'" } }
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

# SIG # Begin signature block
# MIIoYgYJKoZIhvcNAQcCoIIoUzCCKE8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBSs7MyA48cOEnJ
# 3iT3ZaPyqKBGT/VTqbqihJOvq+DbJKCCIV8wggWNMIIEdaADAgECAhAOmxiO+dAt
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
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCBltCGprDkT
# o+VeNabhztf62X+4PotWp/jcXX5wVhsQoTANBgkqhkiG9w0BAQEFAASCAgAuup44
# +d4x6BYwP1xLoY0d561ScdnqRQak9xnrZOJwhxc4gq6iSL0n9rYQbcTWG6G8lUbl
# XObCNp1mNELeCLXQhuzSsbheMlKFAh1PTqnG3b/8f5PUNXB+ZYRjYO50qkGqWOuG
# jBVVfdNcphk5o09KzPN/2eIE63+QCqbv8OsZEbF5Pr78D4Bw2yul5AHNI4kP6SoW
# CLaMHuoC4CeJvwa3PKLv/omtqstLWTKLGUxa+evWRSB/6UpnYkZCCm3YvHlq0VRR
# +mRJWoTIlN/EwqIXEXfIgDonj+66ZEalHTqA4LfWqSaRWc8Cfjjrnmkuzqtxv5yd
# rofvPj3i50xetAluRKHKg7AUtHd5WT8zWf0wdrYcD8o2rMZy7r3RHo5ZcL9Zm7Ke
# cWGUO/OlO3fpjQLvWQLsc3e/upyAVr0N/bYVDEq1OOOjFWDVvHZUPfVrcKTT6N1d
# xkp5eN+z6IGj6hQFJqByg08dxC1UJyf/waO6xe+HmQ3GrxAzr/HQBy8PqIys4EYI
# 4AAr8pbqqbrrkiOe3wSAE74JrJiF4hOeLpknDpN2/GD71iqPWk5WoHZlF3rjH7Gj
# 7Mjm9+eMrHKdKQ6bpsVrqe/rWXf72w4QccPeosFbIg8bRQBKeKsIFihVClhitp62
# CoCMYy5MjANyNRu5shJMdsIEwAXRdy7fXbC5bKGCAyYwggMiBgkqhkiG9w0BCQYx
# ggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcg
# UlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZI
# AWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJ
# BTEPFw0yNTEyMDkwMTEyNDdaMC8GCSqGSIb3DQEJBDEiBCBPtVU3Meo2reCtH5kZ
# YwZMvszxNkshKWbyKu39nMBpiDANBgkqhkiG9w0BAQEFAASCAgBeURMbZa6TmmGk
# ZfcJ7bfrc495ScP1dCHpXlXqogEQDO/5lKPhSQ5xY6QPCSIIMOBtW2mo9DAijvc4
# HoG0y9M0sAE9Fud6MIG1XPYVslO18PJHAWwIOko4KfLJgLyjAk9HGlMarn1vKCBX
# 1Ya7H0IMgXVcMXdXZxml07xpYDfXV+0jFqbfqJzoGYvY18jfL9a88aNvcaidVzEK
# EplZjGsd8us4eqNm0HnIgASB0dOx2QPy8MrBkhILQE92jdroN0YSlSedwU4RlwL/
# 8+tD4KmkfB/+QclXHCeDSgTEfly5yEzahAqYAhEN5E4wSBDx89qGR+5EriJ7Xp2G
# UvTprQk43laG9UtGwknYAhxgwj7yzx62vuedEFuz6S1onyqP9Ka8OFQWr4cC3uvl
# lzLx29ggetl8NtPjt9PyTMV1P+mNhPaYB53F7vayAQ7qxG0QqtYImMWf5yZZhCCM
# x8utFOAvRuFC7BKXdxb4KZp1gydUjNCF3o9WA8VBnYgq2XohFJKzJHkVFWEHEGpC
# +URCsD3v2SYLp+twbm99JvSdSw47hDH3RmRLha257PYdoDc1nEbtrF+WkXIyrZmi
# AyTqU+lvtVcTzusY0f08VGM6WA1KPsVbmDHxpNLdZajTqk65v4zMJ/nlna5HnGig
# uMpzWC3UC/gL2bJ2cricgHcQ2D7Xmg==
# SIG # End signature block
