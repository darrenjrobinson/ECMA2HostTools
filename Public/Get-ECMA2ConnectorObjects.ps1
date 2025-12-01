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
