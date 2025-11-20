<#
.SYNOPSIS
    Example script to send a SCIM user create request to an API connector.

.DESCRIPTION
    This script demonstrates how to use Invoke-ECMA2ConnectorRequest to create
    a user in a connector using SCIM protocol.

.EXAMPLE
    .\Send-CENetUserCreate.ps1 -SecretToken "your-bearer-token-guid"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SecretToken,
    
    [string]$Hostname = 'localhost',
    
    [guid]$RequestIdentifier = (New-Guid),
    
    [guid]$ActivityId = (New-Guid)
)

# Import the module if not already loaded
if (-not (Get-Module -Name ECMA2HostTools)) {
    Import-Module ECMA2HostTools -ErrorAction Stop
}

# Build the request body for a sample user
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
        locale = "EN-US"
        primaryRole = "Manager"
        userName = "jsmith"
        userType = "Employee"
        birthDate = "01-15-1980"
        employeeId = "12345"
        givenName = "John"
        proxyAddresses = "john.smith@example.com"
        sn = "Smith"
        deptNum = "100"
        dept = "IT Department"
        mobile = "+1-555-0100"
        officePhone = "+1-555-0200"
    }
}

# Send the create request to the API connector
try {
    Write-Host "Sending SCIM user create request to APIConnector..." -ForegroundColor Cyan
    Write-Host "User: John Smith (jsmith)" -ForegroundColor Gray
    Write-Host "External ID: 12345" -ForegroundColor Gray
    Write-Host ""
    
    $result = Invoke-ECMA2ConnectorRequest `
        -ConnectorName 'APIConnector' `
        -Method POST `
        -Body $body `
        -SecretToken $SecretToken `
        -Hostname $Hostname `
        -RequestIdentifier $RequestIdentifier `
        -ActivityId $ActivityId
    
    if ($result.Success) {
        Write-Host "✓ User created successfully!" -ForegroundColor Green
        Write-Host "Status Code: $($result.StatusCode)" -ForegroundColor Green
        Write-Host "Request ID: $($result.RequestIdentifier)" -ForegroundColor Gray
        Write-Host "Activity ID: $($result.ActivityId)" -ForegroundColor Gray
        
        if ($result.Response) {
            Write-Host "`nResponse from connector:" -ForegroundColor Cyan
            $result.Response | ConvertTo-Json -Depth 10
        }
    } else {
        Write-Host "✗ Request failed" -ForegroundColor Red
        Write-Host "Status Code: $($result.StatusCode)" -ForegroundColor Red
    }
    
    return $result
    
} catch {
    Write-Host "✗ Error sending request: $_" -ForegroundColor Red
    throw
}
