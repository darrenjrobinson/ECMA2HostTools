function Disconnect-ECMA2Graph {
    <#
    .SYNOPSIS
        Clears the current ECMA2 Graph connection.

    .DESCRIPTION
        Removes the cached Microsoft Graph access token and associated credentials
        established by Connect-ECMA2Graph.

    .EXAMPLE
        Disconnect-ECMA2Graph
    #>
    [CmdletBinding()]
    param()

    if ($script:ECMA2GraphContext) {
        Write-Verbose "Clearing ECMA2 Graph connection ($($script:ECMA2GraphContext.AuthMode))"
        $script:ECMA2GraphContext = $null
    }
    else {
        Write-Verbose "No active ECMA2 Graph connection to clear"
    }
}
