function Get-ECMA2ConnectorObjects {
    <#
    .SYNOPSIS
        Retrieves objects from an ECMA2 connector cache using SCIM queries.

    .DESCRIPTION
        Queries the ECMA2Host service to retrieve objects from a connector's cache,
        similar to how Microsoft Entra provisioning service queries connectors.
        
        Supports filtering by attributes, pagination, and various output formats.
        Requires the connector's secret token for authentication.

    .PARAMETER ConnectorName
        The name of the connector to query.

    .PARAMETER SecretToken
        The secret token for authenticating to the connector (SecureString).
        Can be obtained from Get-ECMA2ConnectorSecret.

    .PARAMETER Port
        The HTTPS port number where ECMA2Host is listening. Defaults to 8585.

    .PARAMETER Hostname
        The hostname of the ECMA2Host server. Defaults to current computer.

    .PARAMETER ObjectTypePath
        The object type collection to query. Defaults to "Users".

    .PARAMETER FilterAttribute
        An attribute name for filtering (e.g., "displayName", "userName", "externalId").

    .PARAMETER FilterValue
        The value to search for when using FilterAttribute (exact match only).
        ECMA2Host only supports exact equality matching via SCIM 'eq' operator.
        For partial matching, use -GetAll and filter results with Where-Object.

    .PARAMETER CustomFilter
        A custom SCIM filter expression (e.g., 'userName eq "user@example.com"').

    .PARAMETER Limit
        Maximum number of objects to retrieve. If not specified, all objects are retrieved.
        Use this to test queries or work with large connectors without fetching everything.

    .PARAMETER ItemsPerPage
        Number of items per page (default 75).

    .PARAMETER StartIndex
        Start index for pagination (default 1).

    .PARAMETER SingleItem
        Return only a single object (useful for diagnostics).

    .PARAMETER SkipCertificateCheck
        Skip SSL certificate validation (for testing environments).

    .PARAMETER CountOnly
        Return only the total count of objects without retrieving the actual objects.
        Efficient for checking connector cache size.

    .PARAMETER ShowDetails
        Show verbose request/response details including headers.

    .PARAMETER InputObject
        Connector object from Get-ECMA2Connector (via pipeline).

    .EXAMPLE
        # Get all objects from a connector (retrieves all pages automatically)
        $secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
        Get-ECMA2Connector -Name "LDAPConnector" | 
            Get-ECMA2ConnectorObjects -SecretToken $secret

    .EXAMPLE
        # Filter objects by attribute (exact match only)
        $secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
        Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
            -FilterAttribute "id" -FilterValue "12345"

    .EXAMPLE
        # Filter using full SCIM extension attribute path
        $secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
        Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
            -FilterAttribute "urn:ietf:params:scim:schemas:extension:ECMA2Host:2.0:User:id" -FilterValue "1"

    .EXAMPLE
        # Partial matching requires retrieving objects and using PowerShell filtering
        # ECMA2Host only supports exact 'eq' matching - retrieve all and use Where-Object for partial matches
        $secret = (Get-ECMA2ConnectorSecret -Name "SQLConnector" -IncludeSecretToken).SecretToken
        
        # Get objects where employeeId starts with "100"
        Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret |
            Where-Object { $_.ECMA2HostAttributes.employeeId -like "100*" }
        
        # Get objects where displayName contains "Smith"
        Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret |
            Where-Object { $_.DisplayName -like "*Smith*" }
        
        # Multiple criteria with PowerShell filtering
        Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret |
            Where-Object { $_.Active -eq $true -and $_.UserName -match '^j' }

    .EXAMPLE
        # Use custom SCIM filter expression (only 'eq' operator supported)
        $secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
        Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
            -CustomFilter 'name eq "John Smith"'

    .EXAMPLE
        # Limit results for testing or initial exploration
        $secret = (Get-ECMA2ConnectorSecret -Name "SQLConnector" -IncludeSecretToken).SecretToken
        
        # Get first 50 objects only
        Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret -Limit 50
        
        # Get first 10 objects to test query
        Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret -Limit 10

    .EXAMPLE
        # Recommended: Retrieve all objects and filter with PowerShell
        # More efficient than multiple exact match queries
        $secret = (Get-ECMA2ConnectorSecret -Name "SQLConnector" -IncludeSecretToken).SecretToken
        
        # Get all objects and filter by multiple criteria
        $users = Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret
        
        # Find users by various patterns
        $users | Where-Object { $_.UserName -like "*admin*" }
        $users | Where-Object { $_.ECMA2HostAttributes.department -eq "IT" -and $_.Active }
        $users | Where-Object { $_.ECMA2HostAttributes.employeeId -gt 10000 }

    .EXAMPLE
        # Get single page of results with custom page size and start index
        $secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
        Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
            -ItemsPerPage 10 -StartIndex 11

    .EXAMPLE
        # Pipeline connector and access ECMA2Host-specific attributes
        $secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
        Get-ECMA2Connector -Name "LDAPConnector" | 
            Get-ECMA2ConnectorObjects -SecretToken $secret | 
            Select-Object Id, @{N='Name';E={$_.ECMA2HostAttributes.displayName}}, @{N='Login';E={$_.ECMA2HostAttributes.userName}}

    .EXAMPLE
        # Show detailed request/response information for diagnostics
        $secret = (Get-ECMA2ConnectorSecret -Name "LDAPConnector" -IncludeSecretToken).SecretToken
        Get-ECMA2ConnectorObjects -ConnectorName "LDAPConnector" -SecretToken $secret `
            -ShowDetails -ItemsPerPage 5

    .EXAMPLE
        # Get only the total count of objects (efficient for validation)
        $secret = (Get-ECMA2ConnectorSecret -Name "SQLConnector" -IncludeSecretToken).SecretToken
        Get-ECMA2ConnectorObjects -ConnectorName "SQLConnector" -SecretToken $secret -CountOnly
        
        # Returns just the integer count, e.g.: 193689
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(ParameterSetName = 'Filter', Mandatory)]
        [Parameter(ParameterSetName = 'CustomFilter', Mandatory)]
        [Parameter(ParameterSetName = 'Default', Mandatory)]
        [string]$ConnectorName,

        [Parameter(ParameterSetName = 'Filter', Mandatory)]
        [Parameter(ParameterSetName = 'CustomFilter', Mandatory)]
        [Parameter(ParameterSetName = 'Default', Mandatory)]
        [Parameter(ParameterSetName = 'FilterFromPipeline', Mandatory)]
        [Parameter(ParameterSetName = 'CustomFilterFromPipeline', Mandatory)]
        [Parameter(ParameterSetName = 'DefaultFromPipeline', Mandatory)]
        [ValidateNotNull()]
        $SecretToken,

        [Parameter()]
        [int]$Port = 8585,

        [Parameter()]
        [string]$Hostname,

        [Parameter()]
        [string]$ObjectTypePath = "Users",

        [Parameter(ParameterSetName = 'Filter', Mandatory)]
        [Parameter(ParameterSetName = 'FilterFromPipeline', Mandatory)]
        [string]$FilterAttribute,

        [Parameter(ParameterSetName = 'Filter', Mandatory)]
        [Parameter(ParameterSetName = 'FilterFromPipeline', Mandatory)]
        [AllowEmptyString()]
        [string]$FilterValue,

        [Parameter(ParameterSetName = 'CustomFilter', Mandatory)]
        [Parameter(ParameterSetName = 'CustomFilterFromPipeline', Mandatory)]
        [string]$CustomFilter,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit,

        [Parameter()]
        [int]$ItemsPerPage = 75,

        [Parameter()]
        [int]$StartIndex = 1,

        [Parameter()]
        [switch]$SingleItem,

        [Parameter()]
        [switch]$SkipCertificateCheck,

        [Parameter()]
        [switch]$CountOnly,

        [Parameter()]
        [switch]$ShowDetails,

        [Parameter(ParameterSetName = 'FilterFromPipeline', ValueFromPipeline, Mandatory)]
        [Parameter(ParameterSetName = 'CustomFilterFromPipeline', ValueFromPipeline, Mandatory)]
        [Parameter(ParameterSetName = 'DefaultFromPipeline', ValueFromPipeline, Mandatory)]
        [PSTypeName('ECMA2Host.Connector')]
        [object]$InputObject
    )

    begin {
        Write-Verbose "Starting Get-ECMA2ConnectorObjects operation"
        
        # Set hostname
        if ([string]::IsNullOrEmpty($Hostname)) {
            $Hostname = [System.Net.Dns]::GetHostName()
        }

        # Handle SSL certificate validation
        if ($SkipCertificateCheck) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            Write-Warning "SSL certificate validation has been disabled for this session"
        }

        # Handle single item override
        if ($SingleItem) {
            $ItemsPerPage = 1
            Write-Verbose "Single item mode enabled - limiting results to 1 object"
        }
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

            Write-Verbose "Querying connector: $targetConnectorName"
            Write-Verbose "Parameter Set: $($PSCmdlet.ParameterSetName)"
            
            if ($Limit) {
                Write-Verbose "Limit: $Limit objects"
            } else {
                Write-Verbose "Limit: Not specified (will retrieve all objects)"
            }

            # Build base URI
            $baseuri = "https://$Hostname`:$Port/ecma2host_$targetConnectorName/scim/$ObjectTypePath"

            # Setup headers with secret token
            $headers = @{}
            
            # Convert SecretToken to string (handle both SecureString and plain string)
            if ($SecretToken -is [SecureString]) {
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecretToken)
                $BearerToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            } elseif ($SecretToken -is [string]) {
                $BearerToken = $SecretToken
            } else {
                throw "SecretToken must be either a SecureString or a String"
            }

            if (-not [string]::IsNullOrEmpty($BearerToken)) {
                $headers["Authorization"] = "Bearer $BearerToken"
            }

            # Build the query URI based on parameters
            $uri = $null
            
            if ($PSBoundParameters.ContainsKey('FilterAttribute')) {
                # Build filter expression using SCIM 'eq' operator (only operator supported by ECMA2Host)
                $filterExpression = "$FilterAttribute eq `"$FilterValue`""
                $encodedFilter = [System.Web.HttpUtility]::UrlEncode($filterExpression)
                $uri = "$baseuri`?filter=$encodedFilter&startIndex=$StartIndex&count=$ItemsPerPage"
                Write-Verbose "Filter: $filterExpression"
                
            } elseif ($CustomFilter) {
                # Use custom filter
                $encodedFilter = [System.Web.HttpUtility]::UrlEncode($CustomFilter)
                $uri = "$baseuri`?filter=$encodedFilter&startIndex=$StartIndex&count=$ItemsPerPage"
                Write-Verbose "Custom Filter: $CustomFilter"
                
            } else {
                # Get all objects (no filter)
                $uri = "$baseuri`?startIndex=$StartIndex&count=$ItemsPerPage"
                Write-Verbose "Retrieving all objects"
            }

            Write-Verbose "Request URI: $uri"

            if ($ShowDetails) {
                Write-Host "`n=== Request Details ===" -ForegroundColor Cyan
                Write-Host "URI: $uri" -ForegroundColor Yellow
                Write-Host "Method: GET" -ForegroundColor Yellow
                Write-Host "Headers:" -ForegroundColor Yellow
                $headers.GetEnumerator() | ForEach-Object {
                    if ($_.Key -eq "Authorization") {
                        Write-Host "  $($_.Key): Bearer [REDACTED]" -ForegroundColor Gray
                    } else {
                        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
                    }
                }
                Write-Host ""
            }

            # Make the request
            $resp = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET -ErrorAction Stop

            if ($ShowDetails) {
                Write-Host "=== Response ===" -ForegroundColor Cyan
                Write-Host "Status Code: $($resp.StatusCode) $($resp.StatusDescription)" -ForegroundColor Green
                Write-Host "`nResponse Headers:" -ForegroundColor Yellow
                $resp.Headers.GetEnumerator() | ForEach-Object {
                    Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
                }

                # Show custom ECMA2Host headers
                if ($resp.Headers['Last-Successful-Import']) {
                    $importValue = $resp.Headers['Last-Successful-Import']
                    if ($importValue -is [array]) { $importValue = $importValue[0] }
                    if (![string]::IsNullOrWhiteSpace($importValue)) {
                        $importTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$importValue).LocalDateTime
                        Write-Host "`nLast Successful Import: $importTime" -ForegroundColor Green
                    }
                }
                if ($resp.Headers['Last-Successful-Export']) {
                    $exportValue = $resp.Headers['Last-Successful-Export']
                    if ($exportValue -is [array]) { $exportValue = $exportValue[0] }
                    if (![string]::IsNullOrWhiteSpace($exportValue)) {
                        $exportTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$exportValue).LocalDateTime
                        Write-Host "Last Successful Export: $exportTime" -ForegroundColor Green
                    }
                }
                if ($resp.Headers['Last-Successful-Cache-Change']) {
                    $cacheValue = $resp.Headers['Last-Successful-Cache-Change']
                    if ($cacheValue -is [array]) { $cacheValue = $cacheValue[0] }
                    if (![string]::IsNullOrWhiteSpace($cacheValue)) {
                        $cacheTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$cacheValue).LocalDateTime
                        Write-Host "Last Successful Cache Change: $cacheTime" -ForegroundColor Green
                    }
                }
                Write-Host ""
            }

            # Parse response
            $responseContent = $resp.Content
            if ($responseContent -is [byte[]]) {
                $responseContent = [System.Text.Encoding]::UTF8.GetString($responseContent)
            }
            elseif ($responseContent -is [object[]]) {
                $responseContent = $responseContent -join ''
            }
            
            $responseObj = $responseContent | ConvertFrom-Json
            
            # Capture Last-Successful timestamps from response headers
            $lastSuccessfulImport = $null
            $lastSuccessfulExport = $null
            $lastSuccessfulCacheChange = $null
            
            if ($resp.Headers['Last-Successful-Import']) {
                $importValue = $resp.Headers['Last-Successful-Import']
                if ($importValue -is [array]) { $importValue = $importValue[0] }
                if (![string]::IsNullOrWhiteSpace($importValue)) {
                    $lastSuccessfulImport = [DateTimeOffset]::FromUnixTimeSeconds([long]$importValue).ToLocalTime().DateTime
                }
            }
            if ($resp.Headers['Last-Successful-Export']) {
                $exportValue = $resp.Headers['Last-Successful-Export']
                if ($exportValue -is [array]) { $exportValue = $exportValue[0] }
                if (![string]::IsNullOrWhiteSpace($exportValue)) {
                    $lastSuccessfulExport = [DateTimeOffset]::FromUnixTimeSeconds([long]$exportValue).ToLocalTime().DateTime
                }
            }
            if ($resp.Headers['Last-Successful-Cache-Change']) {
                $cacheValue = $resp.Headers['Last-Successful-Cache-Change']
                if ($cacheValue -is [array]) { $cacheValue = $cacheValue[0] }
                if (![string]::IsNullOrWhiteSpace($cacheValue)) {
                    $lastSuccessfulCacheChange = [DateTimeOffset]::FromUnixTimeSeconds([long]$cacheValue).ToLocalTime().DateTime
                }
            }

            $totalResults = $responseObj.totalResults
            Write-Verbose "Total Results: $totalResults"
            Write-Verbose "Start Index: $($responseObj.startIndex)"
            Write-Verbose "Items Per Page: $($responseObj.itemsPerPage)"

            # If CountOnly is specified, return just the count with timestamps
            if ($CountOnly) {
                Write-Verbose "CountOnly mode: Returning total count of $totalResults with timestamps"
                return [PSCustomObject]@{
                    TotalCount = $totalResults
                    LastSuccessfulImport = $lastSuccessfulImport
                    LastSuccessfulExport = $lastSuccessfulExport
                    LastSuccessfulCacheChange = $lastSuccessfulCacheChange
                }
            }

            # Track how many objects we've returned
            $objectsReturned = 0
            
            # Return custom objects with metadata
            if ($responseObj.Resources) {
                foreach ($resource in $responseObj.Resources) {
                    # Check if we've hit the limit
                    if ($Limit -and $objectsReturned -ge $Limit) {
                        Write-Verbose "Reached limit of $Limit objects"
                        break
                    }
                    
                    $obj = [PSCustomObject]@{
                        PSTypeName = 'ECMA2Host.ConnectorObject'
                        ConnectorName = $targetConnectorName
                        Id = $resource.id
                        ExternalId = $resource.externalId
                        UserName = $resource.userName
                        DisplayName = $resource.displayName
                        Active = $resource.active
                        Schemas = $resource.schemas
                        Meta = $resource.meta
                        RawObject = $resource
                    }

                    # Add ECMA2Host extension attributes as a separate property
                    $ecmaExtension = $resource.'urn:ietf:params:scim:schemas:extension:ECMA2Host:2.0:User'
                    if ($ecmaExtension) {
                        Add-Member -InputObject $obj -NotePropertyName 'ECMA2HostAttributes' -NotePropertyValue $ecmaExtension
                    }

                    Write-Output $obj
                    $objectsReturned++
                }
            }

            # If no Limit specified and there are more results, fetch remaining pages
            if (-not $Limit -and $totalResults -gt 0) {
                $currentIndex = $StartIndex + $ItemsPerPage
                $itemsRetrieved = $responseObj.Resources.Count
                
                Write-Verbose "Pagination mode: Retrieved $itemsRetrieved of $totalResults total results in first page"
                
                while ($itemsRetrieved -lt $totalResults) {
                    Write-Verbose "Fetching next page: starting at index $currentIndex (retrieved $itemsRetrieved of $totalResults)"
                    
                    # Build URI for next page
                    if ($PSBoundParameters.ContainsKey('FilterAttribute')) {
                        $filterExpression = "$FilterAttribute eq `"$FilterValue`""
                        $encodedFilter = [System.Web.HttpUtility]::UrlEncode($filterExpression)
                        $nextUri = "$baseuri`?filter=$encodedFilter&startIndex=$currentIndex&count=$ItemsPerPage"
                    } elseif ($CustomFilter) {
                        $encodedFilter = [System.Web.HttpUtility]::UrlEncode($CustomFilter)
                        $nextUri = "$baseuri`?filter=$encodedFilter&startIndex=$currentIndex&count=$ItemsPerPage"
                    } else {
                        $nextUri = "$baseuri`?startIndex=$currentIndex&count=$ItemsPerPage"
                    }
                    
                    Write-Verbose "Next page URI: $nextUri"
                    
                    # Make the request for next page
                    $nextResp = Invoke-WebRequest -Uri $nextUri -Headers $headers -Method GET -ErrorAction Stop
                    
                    # Parse response
                    $nextContent = $nextResp.Content
                    if ($nextContent -is [byte[]]) {
                        $nextContent = [System.Text.Encoding]::UTF8.GetString($nextContent)
                    }
                    elseif ($nextContent -is [object[]]) {
                        $nextContent = $nextContent -join ''
                    }
                    
                    $nextResponseObj = $nextContent | ConvertFrom-Json
                    
                    Write-Verbose "Page returned $($nextResponseObj.Resources.Count) objects"
                    
                    # Output objects from this page
                    if ($nextResponseObj.Resources) {
                        foreach ($resource in $nextResponseObj.Resources) {
                            $obj = [PSCustomObject]@{
                                PSTypeName = 'ECMA2Host.ConnectorObject'
                                ConnectorName = $targetConnectorName
                                Id = $resource.id
                                ExternalId = $resource.externalId
                                UserName = $resource.userName
                                DisplayName = $resource.displayName
                                Active = $resource.active
                                Schemas = $resource.schemas
                                Meta = $resource.meta
                                RawObject = $resource
                            }

                            # Add ECMA2Host extension attributes
                            $ecmaExtension = $resource.'urn:ietf:params:scim:schemas:extension:ECMA2Host:2.0:User'
                            if ($ecmaExtension) {
                                Add-Member -InputObject $obj -NotePropertyName 'ECMA2HostAttributes' -NotePropertyValue $ecmaExtension
                            }

                            Write-Output $obj
                            $objectsReturned++
                        }
                        
                        $itemsRetrieved += $nextResponseObj.Resources.Count
                        $currentIndex += $ItemsPerPage
                    } else {
                        # No more results, exit loop
                        Write-Verbose "No more resources in response, stopping pagination"
                        break
                    }
                }
                
                Write-Verbose "Pagination complete: Retrieved all $itemsRetrieved objects"
            } elseif ($Limit) {
                Write-Verbose "Limit specified: Returned $objectsReturned of requested $Limit objects"
            } else {
                Write-Verbose "All results retrieved in first page"
            }

            # Return summary if no results
            if ($totalResults -eq 0) {
                Write-Warning "No objects found matching the criteria"
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
            } elseif ($StatusCode -eq 503) {
                Write-Error "Service unavailable (503). The Microsoft ECMA2Host service may be paused, starting, or stopping."
                Write-Error "Common causes: Configuration Wizard is open, service is transitioning states, or connector '$targetConnectorName' does not exist."
                Write-Warning "Check service status with: Get-Service 'Microsoft ECMA2Host' | Select-Object Status"
                throw
            } elseif ($StatusCode -eq 401) {
                Write-Error "Unauthorized (401). The secret token may be incorrect or expired."
                throw
            } elseif ($StatusCode -eq 400) {
                Write-Error "Bad request (400). Check your filter syntax."
                Write-Error $_.Exception.Message
                throw
            } elseif ($StatusCode -eq 500) {
                Write-Error "Internal server error (500). This may indicate a mapping exception or data type issue in the connector."
                
                # Try to parse mapping exception details
                try {
                    $fullErrorText = $_.ToString()
                    if ($fullErrorText -match '\{\s*"ExceptionMessage"[^}]*"ExceptionType"[^}]*\}') {
                        $errorContent = $matches[0]
                        $errorObj = $errorContent | ConvertFrom-Json -ErrorAction SilentlyContinue
                        if ($errorObj -and $errorObj.ExceptionType -eq "MappingException") {
                            Write-Warning "Mapping Exception: $($errorObj.ExceptionMessage)"
                            Write-Warning "Check connector export script for data type issues or null values in required fields."
                        }
                    }
                }
                catch {
                    Write-Verbose "Could not parse error details: $($_.Exception.Message)"
                }
                
                throw
            } else {
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
        
        Write-Verbose "Get-ECMA2ConnectorObjects operation completed"
    }
}

# SIG # Begin signature block
# MIIoYgYJKoZIhvcNAQcCoIIoUzCCKE8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAKD5FnDhVQxS+s
# j5HjVy9oZK3luGxtvIj0jp+z6SPOL6CCIV8wggWNMIIEdaADAgECAhAOmxiO+dAt
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
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCYJnWDSLTH
# fHU8ZrpUdS4KcqpiGvJ+Kkp60HkyBFjL8zANBgkqhkiG9w0BAQEFAASCAgA9H3Xt
# rwRSPSR0UbpTOE0D0hFznzGO3PaZrpbkiRXLLb6YcEfgR9/v3819uDTRjkhBR5AQ
# tB0q7yU2AVCY+JCKRB2USUW1Yfm5VuLoiXAFrZ+7yjMqb1sY/n6FtvO7/fYlz2Hm
# BOT9PgrsAWejYpbhpmqVTWF+D9xppRbSlRYbzsfzEb21IdCDNgApakXl2HHvO7Mg
# vRKMu++a4oa+CnSfBDoJa3eJI7yTmTnc5nG6wtc6T1g1T44MaM321gKp2bzgzBhq
# 3gMteeWhMltkSmdN1J5o6HoyfRXrhuOj27hvXztyocWcvzjJ0m39vYsWEPg1otTg
# PT7EKpp2udMGOBUwEN9IoZGNiyznrdvaO4/ukyXNCQYLB9pVK13wj/bouVW4QcQm
# vcPGJxpt3eZABaj4SvOOtPBOYpPLtbZzjJsH+sSFY6UCB3kT0oj7hvJDkqc8b+Ke
# AU+XBNbxWLywwDClOrn37fCtSD7V5FK24pmnSubvBSXdDw8yIhiOYAmOhzVMx+U2
# 1IBljE4VfkH70vhfvymJZwu864yXlCSTi8SZJHjqfHrPOYgIguTQy4XZ7sHZiQy7
# NwqkAO1bMUGc86ixgpi06QxLHlGKd9LSg1bkyh+s7BuE3pAE4i83NuCZvwqibdCO
# mMgFaERnp5JjfAtvjAxRWedY4KCCI8fxT8COYqGCAyYwggMiBgkqhkiG9w0BCQYx
# ggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcg
# UlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZI
# AWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJ
# BTEPFw0yNTEyMDkwMTEyNDVaMC8GCSqGSIb3DQEJBDEiBCD/y0vvM3TT9PlQN5up
# UMXFSrpgmTIXwNLPD00DCjou9TANBgkqhkiG9w0BAQEFAASCAgB3yQ2XBIzw4pdh
# /oY/dkVBATOLYXazVz6jmgU+ovCNROdiPO2qWtuJk7fhTV/aHqqrRwq6pQYzCta8
# loz+LL50TnfGHezPT0urOGezKD9/o35Ro9tVQc0lU/WNGaL10QXviIpwrY8ilwWp
# KWe8TqosWMLhgM7fNgbwbheVPuw5oG29fSSnz8LLqVwQXf/P3GNs6p1Mopi+M6wv
# Lfwl8e47INPgKSIQHQdqK1GDdBXGDA1ETQtVLhhKpFVZJDgCIWceBX+ps//N9n1P
# qpBzgpMiAyG3TqILs9blV0AB+BCuc2nFZAll2gX5/42pN0Ittwm3Dzbz/cGH/AII
# rocBsIURfPabce5LMO4GEZTPLx075KXmRcrB/kXlA/Qt/dZDuamxX+ZwVnnk943J
# 1W/ZrnEuBL8q4zKLzOg3KBSQrG7zmUCWs6aCGmootNE3MHGrqBhx8XzQwup413/L
# 5npV9l0WVaFFibuWRW4M/6vqYW4JMV8UfNoGC6MkWD52bi9nPRwSX4oBsBzxjaq3
# p1fbtPPRYSD862atHHE/h1SHDsyWmjPzqziKL/5XeE2o2eLAt2VgAWgRrAV80dfk
# vT+EH61jp8TKm29EZc7car5cgPtF0McHASQ6bn8yIwocoaEz3lSkwF0sf39JRz2f
# cJphiI3D4RGkF4BH/imdSwR5NTYl/g==
# SIG # End signature block
