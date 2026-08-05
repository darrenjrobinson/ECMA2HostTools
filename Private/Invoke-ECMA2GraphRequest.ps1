function Invoke-ECMA2GraphRequest {
    <#
    .SYNOPSIS
        Invokes a Microsoft Graph REST call using the current ECMA2 Graph connection.

    .DESCRIPTION
        Internal function. Thin wrapper over Invoke-RestMethod that attaches the bearer
        token from Get-ECMA2GraphToken, and turns a Graph error response body into a
        readable error message instead of a raw HTTP exception.

    .PARAMETER Method
        The HTTP method to use.

    .PARAMETER Uri
        The full Microsoft Graph request URI.

    .PARAMETER Body
        Optional request body; serialized to JSON.

    .EXAMPLE
        Invoke-ECMA2GraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals/00000000-0000-0000-0000-000000000000/synchronization/jobs/job1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [hashtable]$Body
    )

    $token = Get-ECMA2GraphToken

    $params = @{
        Method  = $Method
        Uri     = $Uri
        Headers = @{ Authorization = "Bearer $token" }
    }

    if ($Body) {
        $params.Body = $Body | ConvertTo-Json -Depth 10
        $params.ContentType = 'application/json'
    }

    try {
        Write-Verbose "$Method $Uri"
        return Invoke-RestMethod @params
    }
    catch {
        $graphError = $null
        if ($_.ErrorDetails.Message) {
            try {
                $graphError = ($_.ErrorDetails.Message | ConvertFrom-Json).error
            }
            catch {
                # Response body wasn't JSON; fall through to the raw exception message
            }
        }

        if ($graphError) {
            throw "Microsoft Graph request failed: $($graphError.code) - $($graphError.message)"
        }
        throw "Microsoft Graph request failed: $_"
    }
}
