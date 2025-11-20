function Get-ECMA2ConnectorRunHistory {
    <#
    .SYNOPSIS
        Gets the run history for an ECMA2 connector.

    .DESCRIPTION
        Retrieves the execution history of run profiles for one or more ECMA2 connectors
        including success/failure status, duration, and statistics.

    .PARAMETER ConnectorName
        The name of the connector. Supports wildcards.

    .PARAMETER RunProfile
        Filter by specific run profile name.

    .PARAMETER Last
        Return only the last N runs. Default is 100.

    .PARAMETER MaxEvents
        Maximum number of events to retrieve from the event log. Default is 1000.
        Increase this value if you need to search further back in history.

    .PARAMETER StartTime
        Return only events after this datetime.

    .PARAMETER EndTime
        Return only events before this datetime.

    .PARAMETER ComputerName
        The name of the computer to query. Default is the local computer.

    .EXAMPLE
        Get-ECMA2ConnectorRunHistory -ConnectorName "SQLConnector"
        Gets run history for the SQLConnector connector from the ECMA2Host event log.

    .EXAMPLE
        Get-ECMA2ConnectorRunHistory -ConnectorName "SQLConnector" -Last 10
        Gets the last 10 runs for the SQLConnector connector.

    .EXAMPLE
        Get-ECMA2ConnectorRunHistory -ConnectorName "*" -RunProfile "Full Import"
        Gets Full Import history for all connectors.

    .EXAMPLE
        Get-ECMA2ConnectorRunHistory -ConnectorName "SQLConnector" -StartTime (Get-Date).AddDays(-7)
        Gets run history for the last 7 days.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [Alias('Name')]
        [string]$ConnectorName = "*",

        [Parameter()]
        [string]$RunProfile,

        [Parameter()]
        [int]$Last = 100,

        [Parameter()]
        [int]$MaxEvents = 1000,

        [Parameter()]
        [datetime]$StartTime,

        [Parameter()]
        [datetime]$EndTime,

        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    begin {
        Write-Verbose "Getting ECMA2 connector run history from event log"
    }

    process {
        try {
            Write-Verbose "Querying run history for connector '$ConnectorName' on $ComputerName"
            
            # Build filter hashtable for Get-WinEvent
            $filterHashtable = @{
                LogName = 'ECMA2Host'
            }
            
            # Add time filters if specified
            if ($StartTime) {
                $filterHashtable['StartTime'] = $StartTime
                Write-Verbose "Filtering events after: $StartTime"
            }
            
            if ($EndTime) {
                $filterHashtable['EndTime'] = $EndTime
                Write-Verbose "Filtering events before: $EndTime"
            }
            
            # If specific connector requested, filter by ProviderName for efficiency
            if ($ConnectorName -ne "*" -and -not [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($ConnectorName)) {
                $filterHashtable['ProviderName'] = "ECMA2Host.$ConnectorName"
                Write-Verbose "Filtering by ProviderName: ECMA2Host.$ConnectorName"
            }
            
            # Get events from the ECMA2Host log
            Write-Verbose "Querying ECMA2Host event log on $ComputerName"
            
            $getEventParams = @{
                FilterHashtable = $filterHashtable
                MaxEvents = $MaxEvents
                ErrorAction = 'Stop'
            }
            
            if ($ComputerName -ne $env:COMPUTERNAME) {
                $getEventParams['ComputerName'] = $ComputerName
            }
            
            try {
                $events = Get-WinEvent @getEventParams
            }
            catch [Exception] {
                if ($_.Exception.Message -like "*No events were found*") {
                    Write-Warning "No events found in ECMA2Host log on $ComputerName"
                    return
                }
                elseif ($_.Exception.Message -like "*does not exist*") {
                    Write-Warning "ECMA2Host event log does not exist on $ComputerName. Ensure ECMA2Host is installed and has run at least once."
                    return
                }
                else {
                    throw
                }
            }
            
            if (-not $events) {
                Write-Verbose "No events found matching criteria"
                return
            }
            
            Write-Verbose "Retrieved $($events.Count) events from ECMA2Host log"
            
            # Parse events and filter
            $runHistory = @()
            
            foreach ($event in $events) {
                # Extract connector name from ProviderName (e.g., "ECMA2Host.SQLConnector" -> "SQLConnector")
                $providerName = $event.ProviderName
                $eventConnectorName = $null
                
                if ($providerName -match '^ECMA2Host\.(.+)$') {
                    $eventConnectorName = $matches[1]
                }
                elseif ($providerName -eq 'ECMA2Host.Library') {
                    # ECMA2Host.Library logs general service events - skip unless explicitly requested
                    if ($ConnectorName -ne '*' -and $ConnectorName -ne 'Library') {
                        continue
                    }
                    $eventConnectorName = 'Library'
                }
                else {
                    # Skip events without recognizable provider (MainDomain, ConfigWizard, etc.)
                    continue
                }
                
                # Filter by connector name with wildcard support
                if ($ConnectorName -ne "*" -and $eventConnectorName -notlike $ConnectorName) {
                    continue
                }
                
                # Parse the event message to extract run profile and action
                $message = $event.Message
                $eventRunProfile = $null
                $eventAction = $null
                
                # Extract run profile from "Method Name : <Class> : <Method>" pattern
                if ($message -match "Method Name\s*:\s*([^:]+)\s*:\s*([^:\r\n]+)") {
                    $eventClass = $matches[1].Trim()
                    $eventMethod = $matches[2].Trim()
                    
                    # For connector events, the method often indicates the operation
                    $eventRunProfile = $eventMethod
                    
                    # Extract action from common patterns
                    if ($message -match "(Import|Export|Full Import|Delta Import|Full Synchronization|Delta Synchronization)") {
                        $eventAction = $matches[1]
                    }
                }
                
                # Filter by run profile if specified
                if ($RunProfile -and $eventRunProfile -notlike $RunProfile) {
                    continue
                }
                
                # Determine status from event level and message content
                $status = switch ($event.Level) {
                    1 { 'Critical' }
                    2 { 'Error' }
                    3 { 'Warning' }
                    4 { 'Information' }
                    5 { 'Verbose' }
                    default { 'Unknown' }
                }
                
                # Check for success/failure indicators in message
                if ($message -match "\bsuccess\b|\bcompleted\b|\bfinished\b" -and $message -notmatch "\berror\b|\bfail") {
                    $status = 'Success'
                }
                elseif ($message -match "\berror\b|\bfail|\bexception\b") {
                    $status = 'Error'
                }
                
                # Create run history object
                $historyEntry = [PSCustomObject]@{
                    TimeCreated = $event.TimeCreated
                    ConnectorName = $eventConnectorName
                    RunProfile = $eventRunProfile
                    Action = $eventAction
                    Status = $status
                    Message = $message
                    EventId = $event.Id
                    Level = $event.LevelDisplayName
                    ProviderName = $event.ProviderName
                    ComputerName = $event.MachineName
                    ProcessId = $event.ProcessId
                    ThreadId = $event.ThreadId
                }
                
                $historyEntry.PSObject.TypeNames.Insert(0, 'ECMA2Host.ConnectorRunHistory')
                $runHistory += $historyEntry
            }
            
            # Apply Last filter if specified
            if ($Last -and $runHistory.Count -gt $Last) {
                Write-Verbose "Limiting results to last $Last entries"
                $runHistory = $runHistory | Select-Object -First $Last
            }
            
            Write-Verbose "Returning $($runHistory.Count) run history entries"
            return $runHistory
        }
        catch {
            Write-Error "Failed to get run history for connector '$ConnectorName': $_"
        }
    }

    end {
        Write-Verbose "Get-ECMA2ConnectorRunHistory operation completed"
    }
}
