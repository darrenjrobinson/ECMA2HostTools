function ConvertTo-ECMA2LocalDateTime {
    <#
    .SYNOPSIS
        Converts a Microsoft Graph timestamp to a DateTime in the system's local time zone.

    .DESCRIPTION
        Internal function. Microsoft Graph returns timestamps as ISO 8601 UTC strings.
        PowerShell 7 deserializes them to a UTC DateTime, while Windows PowerShell 5.1
        leaves them as strings. This accepts either form (or a DateTimeOffset) and
        returns a DateTime of Kind Local, or $null when no value is supplied.

        Local DateTime values are for display. Don't compare them to order two
        timestamps: during the daylight-saving fall-back hour a later instant can have
        an earlier local clock time. Use -AsUtc to get the instant for comparisons.

    .PARAMETER Value
        The timestamp to convert: an ISO 8601 string, a DateTime, or a DateTimeOffset.

    .PARAMETER AsUtc
        Return the timestamp as a DateTime of Kind Utc instead of local time.

    .EXAMPLE
        ConvertTo-ECMA2LocalDateTime -Value '2026-01-01T00:00:00Z'

    .EXAMPLE
        ConvertTo-ECMA2LocalDateTime -Value '2026-01-01T00:00:00Z' -AsUtc
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value,

        [Parameter()]
        [switch]$AsUtc
    )

    if ($null -eq $Value) {
        return $null
    }

    # Normalize every accepted form to a UTC DateTime first
    $utc = $null

    if ($Value -is [datetime]) {
        # A timestamp with no kind came from Graph, which is always UTC
        if ($Value.Kind -eq [System.DateTimeKind]::Unspecified) {
            $utc = [datetime]::SpecifyKind($Value, [System.DateTimeKind]::Utc)
        }
        else {
            $utc = $Value.ToUniversalTime()
        }
    }
    elseif ($Value -is [System.DateTimeOffset]) {
        $utc = $Value.UtcDateTime
    }
    else {
        $text = [string]$Value
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }

        $parsed = [System.DateTimeOffset]::MinValue
        $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal
        if (-not [System.DateTimeOffset]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
            Write-Verbose "Could not parse '$text' as a timestamp"
            return $null
        }
        $utc = $parsed.UtcDateTime
    }

    # Graph reports "no value yet" (e.g. the end time of a run still in progress) as
    # 0001-01-01T00:00:00Z rather than null; treat that sentinel as no value
    if ($utc.Year -le 1) {
        return $null
    }

    if ($AsUtc) {
        return $utc
    }
    return $utc.ToLocalTime()
}
