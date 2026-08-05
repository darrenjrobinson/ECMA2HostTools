function Get-ECMA2GraphToken {
    <#
    .SYNOPSIS
        Returns a valid Microsoft Graph access token for the current ECMA2 Graph connection.

    .DESCRIPTION
        Internal function. Returns the cached access token established by
        Connect-ECMA2Graph, transparently refreshing it first if it is at or near expiry.

    .EXAMPLE
        Get-ECMA2GraphToken
    #>
    [CmdletBinding()]
    param()

    if (-not $script:ECMA2GraphContext) {
        throw "Not connected to Microsoft Graph. Run Connect-ECMA2Graph first."
    }

    $context = $script:ECMA2GraphContext

    if ((Get-Date) -lt $context.ExpiresOn.AddMinutes(-1)) {
        return $context.AccessToken
    }

    Write-Verbose "Access token expired or expiring soon, refreshing ($($context.AuthMode))"
    $tokenEndpoint = "https://login.microsoftonline.com/$($context.TenantId)/oauth2/v2.0/token"

    try {
        switch ($context.AuthMode) {
            'DeviceCode' {
                if (-not $context.RefreshToken) {
                    throw "No refresh token available. Run Connect-ECMA2Graph again to re-authenticate."
                }
                $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body @{
                    grant_type    = 'refresh_token'
                    client_id     = $context.ClientId
                    refresh_token = $context.RefreshToken
                    scope         = ($context.Scopes -join ' ')
                } -ContentType 'application/x-www-form-urlencoded'
                # Some refresh responses omit refresh_token (the identity platform may
                # reuse the existing one) - only overwrite it when a new value is
                # actually returned, otherwise the cached refresh token would be wiped
                # out and the next refresh would fail.
                if ($response.refresh_token) {
                    $context.RefreshToken = $response.refresh_token
                }
            }
            'ClientSecret' {
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($context.ClientSecret)
                $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

                $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body @{
                    grant_type    = 'client_credentials'
                    client_id     = $context.ClientId
                    client_secret = $plainSecret
                    scope         = 'https://graph.microsoft.com/.default'
                } -ContentType 'application/x-www-form-urlencoded'
            }
            'Certificate' {
                $assertion = New-ECMA2GraphClientAssertion -ClientId $context.ClientId -TenantId $context.TenantId -Certificate $context.Certificate
                $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body @{
                    grant_type            = 'client_credentials'
                    client_id             = $context.ClientId
                    client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
                    client_assertion      = $assertion
                    scope                 = 'https://graph.microsoft.com/.default'
                } -ContentType 'application/x-www-form-urlencoded'
            }
            'AccessToken' {
                throw "The current connection uses a bring-your-own access token and cannot be refreshed automatically. Run Connect-ECMA2Graph -AccessToken with a fresh token."
            }
            default {
                throw "Unknown ECMA2 Graph authentication mode '$($context.AuthMode)'. Run Connect-ECMA2Graph again."
            }
        }

        $context.AccessToken = $response.access_token
        $context.ExpiresOn = (Get-Date).AddSeconds($response.expires_in)
        return $context.AccessToken
    }
    catch {
        throw "Failed to refresh Microsoft Graph access token: $_"
    }
}
