function Connect-ECMA2Graph {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph for cloud provisioning synchronization job management.

    .DESCRIPTION
        Establishes an access token used by Get-ECMA2ConnectorSyncJob and
        Restart-ECMA2ConnectorSyncJob. No Microsoft Graph SDK or MSAL dependency is
        required - authentication is performed with direct REST calls against the
        Microsoft identity platform v2.0 endpoint, keeping this module dependency-free.

        Four mutually exclusive authentication modes are supported:
        - Interactive (default): device code flow using delegated user permissions -
          the same sign-in experience as Graph Explorer. No app registration required
          unless your tenant restricts the well-known Microsoft Graph PowerShell client.
        - ClientSecret: app-only client credentials using a client secret, for automation.
        - Certificate: app-only client credentials using a signed JWT certificate
          assertion, for automation without storing a shared secret.
        - AccessToken: use a token already obtained some other way (e.g. copied from
          Graph Explorer). This mode cannot self-refresh; reconnect when it expires.
          ExpiresOn is read from the token's own 'exp' claim when it's a parseable
          JWT, falling back to 60 minutes from now otherwise.

    .PARAMETER TenantId
        The tenant ID or verified domain to authenticate against. Defaults to
        'organizations' for interactive sign-in. Required for ClientSecret and
        Certificate modes.

    .PARAMETER ClientId
        The application (client) ID to authenticate as. Defaults to the well-known
        Microsoft Graph PowerShell client ID for interactive sign-in. Required for
        ClientSecret and Certificate modes.

    .PARAMETER Scopes
        Delegated scopes to request in Interactive mode. Defaults to
        'Synchronization.ReadWrite.All' plus 'offline_access' (needed to obtain a
        refresh token).

    .PARAMETER ClientSecret
        App-only authentication: the application's client secret.

    .PARAMETER CertificateThumbprint
        App-only authentication: thumbprint of a certificate (with private key) in
        Cert:\CurrentUser\My or Cert:\LocalMachine\My.

    .PARAMETER Certificate
        App-only authentication: an X509Certificate2 object (with private key) to sign with.

    .PARAMETER AccessToken
        Bring-your-own bearer token, as a SecureString.

    .EXAMPLE
        Connect-ECMA2Graph
        Signs in interactively via device code, matching the Graph Explorer experience.

    .EXAMPLE
        Connect-ECMA2Graph -TenantId contoso.onmicrosoft.com -ClientId $appId -ClientSecret (Read-Host -AsSecureString)
        Connects using app-only client credentials for unattended automation.

    .EXAMPLE
        Connect-ECMA2Graph -TenantId contoso.onmicrosoft.com -ClientId $appId -CertificateThumbprint $thumbprint
        Connects using app-only certificate authentication.

    .NOTES
        Requires the app registration (for ClientSecret/Certificate modes) or the
        signed-in delegated user (for Interactive mode) to hold Synchronization.ReadWrite.All,
        and for delegated sign-in the user must also be an owner/member of the target
        service principal or hold Application Administrator, Cloud Application
        Administrator, or Hybrid Identity Administrator.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'ClientSecret', Mandatory)]
        [Parameter(ParameterSetName = 'Certificate', Mandatory)]
        [string]$TenantId = 'organizations',

        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'ClientSecret', Mandatory)]
        [Parameter(ParameterSetName = 'Certificate', Mandatory)]
        [string]$ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e',

        [Parameter(ParameterSetName = 'Interactive')]
        [string[]]$Scopes = @('Synchronization.ReadWrite.All', 'offline_access'),

        [Parameter(ParameterSetName = 'ClientSecret', Mandatory)]
        [SecureString]$ClientSecret,

        [Parameter(ParameterSetName = 'Certificate')]
        [string]$CertificateThumbprint,

        [Parameter(ParameterSetName = 'Certificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(ParameterSetName = 'AccessToken', Mandatory)]
        [SecureString]$AccessToken
    )

    # One web session shared by every call for this connection, so (on PowerShell 7.4+)
    # the underlying HTTP connection is pooled and reused. Without it each request opens a
    # new connection, and on hosts where IPv6 resolves but doesn't route, every connection
    # waits out the IPv6 attempts (minutes) before falling back to IPv4 - long enough for
    # device code polling to stall and sign-in to fail with AADSTS70008.
    $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    try {
        switch ($PSCmdlet.ParameterSetName) {
            'Interactive' {
                $deviceCodeEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode"
                $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

                Write-Verbose "Requesting device code from $deviceCodeEndpoint"
                $requestStart = Get-Date
                $deviceCodeResponse = Invoke-RestMethod -Method Post -Uri $deviceCodeEndpoint -Body @{
                    client_id = $ClientId
                    scope     = ($Scopes -join ' ')
                } -ContentType 'application/x-www-form-urlencoded' -WebSession $webSession

                $requestSeconds = [int]((Get-Date) - $requestStart).TotalSeconds
                Write-Verbose "Device code request took $requestSeconds seconds"
                if ($requestSeconds -gt 15) {
                    Write-Warning ("Connecting to login.microsoftonline.com took $requestSeconds seconds. " +
                        "This is usually IPv6 being resolved but not routable, forcing a slow fallback to IPv4. " +
                        "To prefer IPv4 system-wide (admin, reboot required): " +
                        "New-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters -Name DisabledComponents -Value 0x20 -PropertyType DWord -Force")
                }

                Write-Host $deviceCodeResponse.message -ForegroundColor Cyan

                $expiresAt = (Get-Date).AddSeconds($deviceCodeResponse.expires_in)
                $tokenResponse = $null
                $pollingInterval = $deviceCodeResponse.interval

                while ((Get-Date) -lt $expiresAt) {
                    Start-Sleep -Seconds $pollingInterval
                    try {
                        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body @{
                            grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
                            client_id   = $ClientId
                            device_code = $deviceCodeResponse.device_code
                        } -ContentType 'application/x-www-form-urlencoded' -WebSession $webSession
                        break
                    }
                    catch {
                        $errorBody = $null
                        if ($_.ErrorDetails.Message) {
                            $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
                        }
                        if ($errorBody -and $errorBody.error -eq 'authorization_pending') {
                            continue
                        }
                        if ($errorBody -and $errorBody.error -eq 'slow_down') {
                            # Per RFC 8628, back off polling by 5 seconds and keep waiting.
                            $pollingInterval += 5
                            continue
                        }
                        if ($errorBody -and $errorBody.error_description) {
                            throw "Device code sign-in failed: $($errorBody.error_description)"
                        }
                        throw "Device code sign-in failed: $_"
                    }
                }

                if (-not $tokenResponse) {
                    throw "Device code sign-in timed out before completion."
                }

                $script:ECMA2GraphContext = [PSCustomObject]@{
                    AuthMode     = 'DeviceCode'
                    TenantId     = $TenantId
                    ClientId     = $ClientId
                    AccessToken  = $tokenResponse.access_token
                    RefreshToken = $tokenResponse.refresh_token
                    Certificate  = $null
                    ClientSecret = $null
                    Scopes       = $Scopes
                    ExpiresOn    = (Get-Date).AddSeconds($tokenResponse.expires_in)
                    WebSession   = $webSession
                }
            }
            'ClientSecret' {
                $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)
                $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

                $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body @{
                    grant_type    = 'client_credentials'
                    client_id     = $ClientId
                    client_secret = $plainSecret
                    scope         = 'https://graph.microsoft.com/.default'
                } -ContentType 'application/x-www-form-urlencoded' -WebSession $webSession

                $script:ECMA2GraphContext = [PSCustomObject]@{
                    AuthMode     = 'ClientSecret'
                    TenantId     = $TenantId
                    ClientId     = $ClientId
                    AccessToken  = $tokenResponse.access_token
                    RefreshToken = $null
                    Certificate  = $null
                    ClientSecret = $ClientSecret
                    Scopes       = @('https://graph.microsoft.com/.default')
                    ExpiresOn    = (Get-Date).AddSeconds($tokenResponse.expires_in)
                    WebSession   = $webSession
                }
            }
            'Certificate' {
                if (-not $Certificate) {
                    if (-not $CertificateThumbprint) {
                        throw "Specify either -Certificate or -CertificateThumbprint."
                    }
                    $Certificate = Get-Item -Path "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
                    if (-not $Certificate) {
                        $Certificate = Get-Item -Path "Cert:\LocalMachine\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
                    }
                    if (-not $Certificate) {
                        throw "Certificate with thumbprint '$CertificateThumbprint' not found in CurrentUser\My or LocalMachine\My."
                    }
                }

                $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
                $assertion = New-ECMA2GraphClientAssertion -ClientId $ClientId -TenantId $TenantId -Certificate $Certificate

                $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body @{
                    grant_type            = 'client_credentials'
                    client_id             = $ClientId
                    client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
                    client_assertion      = $assertion
                    scope                 = 'https://graph.microsoft.com/.default'
                } -ContentType 'application/x-www-form-urlencoded' -WebSession $webSession

                $script:ECMA2GraphContext = [PSCustomObject]@{
                    AuthMode     = 'Certificate'
                    TenantId     = $TenantId
                    ClientId     = $ClientId
                    AccessToken  = $tokenResponse.access_token
                    RefreshToken = $null
                    Certificate  = $Certificate
                    ClientSecret = $null
                    Scopes       = @('https://graph.microsoft.com/.default')
                    ExpiresOn    = (Get-Date).AddSeconds($tokenResponse.expires_in)
                    WebSession   = $webSession
                }
            }
            'AccessToken' {
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)
                $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

                # Best-effort: read the 'exp' claim out of the JWT payload so ExpiresOn
                # reflects the token's real expiry rather than an arbitrary guess. Falls
                # back to a 60-minute default if the token isn't a parseable JWT.
                $expiresOn = (Get-Date).AddMinutes(60)
                try {
                    $payload = $plainToken.Split('.')[1]
                    $payload = $payload.Replace('-', '+').Replace('_', '/')
                    switch ($payload.Length % 4) {
                        2 { $payload += '==' }
                        3 { $payload += '=' }
                    }
                    $claims = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload)) | ConvertFrom-Json
                    if ($claims.exp) {
                        $expiresOn = [System.DateTimeOffset]::FromUnixTimeSeconds([int64]$claims.exp).LocalDateTime
                    }
                }
                catch {
                    Write-Verbose "Could not parse an 'exp' claim from the supplied access token; defaulting ExpiresOn to 60 minutes from now."
                }

                $script:ECMA2GraphContext = [PSCustomObject]@{
                    AuthMode     = 'AccessToken'
                    TenantId     = $null
                    ClientId     = $null
                    AccessToken  = $plainToken
                    RefreshToken = $null
                    Certificate  = $null
                    ClientSecret = $null
                    Scopes       = @()
                    ExpiresOn    = $expiresOn
                    WebSession   = $webSession
                }
                Write-Warning "Bring-your-own access token cannot be automatically refreshed. Reconnect with a fresh token if requests start failing with 401 or once ExpiresOn ($expiresOn) passes."
            }
        }

        Write-Verbose "Connected to Microsoft Graph using $($script:ECMA2GraphContext.AuthMode) authentication"

        [PSCustomObject]@{
            PSTypeName = 'ECMA2Host.GraphContext'
            AuthMode   = $script:ECMA2GraphContext.AuthMode
            TenantId   = $script:ECMA2GraphContext.TenantId
            ClientId   = $script:ECMA2GraphContext.ClientId
            Scopes     = $script:ECMA2GraphContext.Scopes
            ExpiresOn  = $script:ECMA2GraphContext.ExpiresOn
        }
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
    }
}
