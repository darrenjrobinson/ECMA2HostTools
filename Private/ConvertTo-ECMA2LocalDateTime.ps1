function ConvertTo-ECMA2LocalDateTime {
    <#
    .SYNOPSIS
        Converts a Microsoft Graph timestamp to a DateTime in the system's local time zone.

    .DESCRIPTION
        Internal function. Microsoft Graph returns timestamps as ISO 8601 UTC strings.
        PowerShell 7 deserializes them to a UTC DateTime, while Windows PowerShell 5.1
        leaves them as strings. This accepts either form (or a DateTimeOffset) and
        returns a DateTime of Kind Local, or $null when no value is supplied.

    .PARAMETER Value
        The timestamp to convert: an ISO 8601 string, a DateTime, or a DateTimeOffset.

    .EXAMPLE
        ConvertTo-ECMA2LocalDateTime -Value '2026-01-01T00:00:00Z'
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    # Graph reports "no value yet" (e.g. the end time of a run still in progress) as
    # 0001-01-01T00:00:00Z rather than null; treat that sentinel as no value
    if (($Value -is [datetime] -or $Value -is [System.DateTimeOffset]) -and $Value.Year -le 1) {
        return $null
    }

    if ($Value -is [datetime]) {
        # A timestamp with no kind came from Graph, which is always UTC
        if ($Value.Kind -eq [System.DateTimeKind]::Unspecified) {
            $Value = [datetime]::SpecifyKind($Value, [System.DateTimeKind]::Utc)
        }
        return $Value.ToLocalTime()
    }

    if ($Value -is [System.DateTimeOffset]) {
        return $Value.LocalDateTime
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    $parsed = [System.DateTimeOffset]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal
    if ([System.DateTimeOffset]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
        if ($parsed.Year -le 1) {
            return $null
        }
        return $parsed.LocalDateTime
    }

    Write-Verbose "Could not parse '$text' as a timestamp"
    return $null
}
