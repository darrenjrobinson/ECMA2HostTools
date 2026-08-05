function New-ECMA2GraphClientAssertion {
    <#
    .SYNOPSIS
        Builds and signs a JWT client assertion for Microsoft Entra app-only certificate authentication.

    .DESCRIPTION
        Internal function. Creates a short-lived RS256-signed JWT bearer assertion from
        the supplied certificate, per the OAuth2 client credentials + client assertion
        flow, without requiring MSAL or the Microsoft.Graph SDK.

    .PARAMETER ClientId
        The application (client) ID of the Entra app registration.

    .PARAMETER TenantId
        The tenant ID or domain the app is registered in.

    .PARAMETER Certificate
        The X509Certificate2 (with private key) to sign the assertion with.

    .EXAMPLE
        New-ECMA2GraphClientAssertion -ClientId $id -TenantId $tenant -Certificate $cert
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ClientId,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    try {
        $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        $now = [DateTimeOffset]::UtcNow
        $x5t = [Convert]::ToBase64String($Certificate.GetCertHash()).TrimEnd('=').Replace('+', '-').Replace('/', '_')

        $header = @{
            alg = 'RS256'
            typ = 'JWT'
            x5t = $x5t
        } | ConvertTo-Json -Compress

        $payload = @{
            aud = $tokenEndpoint
            iss = $ClientId
            sub = $ClientId
            jti = [guid]::NewGuid().ToString()
            nbf = $now.ToUnixTimeSeconds()
            exp = $now.AddMinutes(10).ToUnixTimeSeconds()
            iat = $now.ToUnixTimeSeconds()
        } | ConvertTo-Json -Compress

        $encodedHeader = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($header)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        $encodedPayload = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payload)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        $unsignedToken = "$encodedHeader.$encodedPayload"

        # $Certificate.GetRSAPrivateKey() is a C# extension method - PowerShell's dot-notation
        # method resolution doesn't see extension methods (in either Windows PowerShell 5.1 or
        # PowerShell 7), so it must be invoked as a static call on the extension class instead.
        $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
        if (-not $rsa) {
            throw "Certificate does not have an accessible RSA private key."
        }

        $signature = $rsa.SignData(
            [System.Text.Encoding]::UTF8.GetBytes($unsignedToken),
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        )
        $encodedSignature = [Convert]::ToBase64String($signature).TrimEnd('=').Replace('+', '-').Replace('/', '_')

        return "$unsignedToken.$encodedSignature"
    }
    catch {
        throw "Failed to build client assertion JWT: $_"
    }
}
