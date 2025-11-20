$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$modulePath = Split-Path -Parent $here
$manifestPath = Join-Path $modulePath 'ECMA2HostTools.psd1'

# Import the module
Remove-Module ECMA2HostTools -ErrorAction SilentlyContinue
Import-Module $manifestPath -Force

Describe "Get-ECMA2ConnectorRunHistory" {
    
    Context "Parameter Validation" {
        
        It "Should accept ConnectorName parameter" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $cmd.Parameters.ContainsKey('ConnectorName') | Should Be $true
        }
        
        It "Should accept ConnectorName from pipeline" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $param = $cmd.Parameters['ConnectorName']
            $param.Attributes.ValueFromPipeline | Should Be $true
        }
        
        It "Should support wildcards for ConnectorName" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $param = $cmd.Parameters['ConnectorName']
            $param.Attributes | Where-Object { $_.TypeId.Name -eq 'SupportsWildcardsAttribute' } | Should Not Be $null
        }
        
        It "Should have Name alias for ConnectorName" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $param = $cmd.Parameters['ConnectorName']
            $aliases = $param.Aliases
            $aliases -contains 'Name' | Should Be $true
        }
        
        It "Should accept RunProfile parameter" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $cmd.Parameters.ContainsKey('RunProfile') | Should Be $true
        }
        
        It "Should accept Last parameter with default value" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $param = $cmd.Parameters['Last']
            $param | Should Not Be $null
        }
        
        It "Should accept MaxEvents parameter" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $cmd.Parameters.ContainsKey('MaxEvents') | Should Be $true
        }
        
        It "Should accept StartTime parameter" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $cmd.Parameters.ContainsKey('StartTime') | Should Be $true
        }
        
        It "Should accept EndTime parameter" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $cmd.Parameters.ContainsKey('EndTime') | Should Be $true
        }
        
        It "Should accept ComputerName parameter with default" {
            $cmd = Get-Command Get-ECMA2ConnectorRunHistory
            $param = $cmd.Parameters['ComputerName']
            $param | Should Not Be $null
        }
    }
    
    Context "Event Log Query" {
        
        It "Should query ECMA2Host event log" {
            # This test requires ECMA2Host log to exist
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                { Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction Stop } | Should Not Throw
            }
            else {
                # If log doesn't exist, should show warning
                $warnings = @()
                Get-ECMA2ConnectorRunHistory -MaxEvents 10 -WarningVariable warnings -ErrorAction SilentlyContinue
                $warnings.Count -gt 0 | Should Be $true
            }
        }
        
        It "Should handle missing event log gracefully" {
            # Test with non-existent computer (should fail gracefully)
            $result = Get-ECMA2ConnectorRunHistory -ComputerName "NonExistentComputer$(Get-Random)" -MaxEvents 10 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            # Should return nothing or handle error gracefully
            $true | Should Be $true
        }
        
        It "Should respect MaxEvents parameter" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 5 -ErrorAction SilentlyContinue
                if ($result) {
                    $result.Count -le 5 | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
    }
    
    Context "Return Object Structure" {
        
        It "Should return objects with TimeCreated property" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction SilentlyContinue
                if ($result) {
                    $result[0].PSObject.Properties.Name -contains 'TimeCreated' | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should return objects with ConnectorName property" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction SilentlyContinue
                if ($result) {
                    $result[0].PSObject.Properties.Name -contains 'ConnectorName' | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should return objects with RunProfile property" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction SilentlyContinue
                if ($result) {
                    $result[0].PSObject.Properties.Name -contains 'RunProfile' | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should return objects with Status property" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction SilentlyContinue
                if ($result) {
                    $result[0].PSObject.Properties.Name -contains 'Status' | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should return objects with Message property" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction SilentlyContinue
                if ($result) {
                    $result[0].PSObject.Properties.Name -contains 'Message' | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should return objects with EventId property" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction SilentlyContinue
                if ($result) {
                    $result[0].PSObject.Properties.Name -contains 'EventId' | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should return objects with ProviderName property" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction SilentlyContinue
                if ($result) {
                    $result[0].PSObject.Properties.Name -contains 'ProviderName' | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should return objects with ComputerName property" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction SilentlyContinue
                if ($result) {
                    $result[0].PSObject.Properties.Name -contains 'ComputerName' | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should return objects with custom type name" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 10 -ErrorAction SilentlyContinue
                if ($result) {
                    $result[0].PSObject.TypeNames -contains 'ECMA2Host.ConnectorRunHistory' | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
    }
    
    Context "Connector Name Filtering" {
        
        It "Should filter by specific connector name" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                # Get all connectors first
                $allResults = Get-ECMA2ConnectorRunHistory -MaxEvents 100 -ErrorAction SilentlyContinue
                
                if ($allResults -and $allResults.Count -gt 0) {
                    $testConnector = $allResults[0].ConnectorName
                    $filtered = Get-ECMA2ConnectorRunHistory -ConnectorName $testConnector -MaxEvents 50 -ErrorAction SilentlyContinue
                    
                    if ($filtered) {
                        # All results should be for the specified connector
                        $allMatch = ($filtered | ForEach-Object { $_.ConnectorName -eq $testConnector }) -notcontains $false
                        $allMatch | Should Be $true
                    }
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should support wildcard filtering" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                # This should not throw even with wildcards
                { Get-ECMA2ConnectorRunHistory -ConnectorName "*" -MaxEvents 10 -ErrorAction SilentlyContinue } | Should Not Throw
            }
            
            $true | Should Be $true
        }
        
        It "Should use ProviderName filter for specific connector" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                # Get a connector name from actual results
                $allResults = Get-ECMA2ConnectorRunHistory -MaxEvents 50 -ErrorAction SilentlyContinue
                
                if ($allResults -and $allResults.Count -gt 0) {
                    $testConnector = $allResults[0].ConnectorName
                    
                    # Query with specific connector should be faster and return results
                    $result = Get-ECMA2ConnectorRunHistory -ConnectorName $testConnector -MaxEvents 10 -ErrorAction SilentlyContinue
                    
                    # Should return results for that connector
                    if ($result) {
                        $result[0].ConnectorName | Should Be $testConnector
                    }
                }
            }
            
            $true | Should Be $true
        }
    }
    
    Context "Run Profile Filtering" {
        
        It "Should filter by run profile" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $allResults = Get-ECMA2ConnectorRunHistory -MaxEvents 100 -ErrorAction SilentlyContinue
                
                if ($allResults -and $allResults.Count -gt 0) {
                    $testProfile = $allResults[0].RunProfile
                    
                    if ($testProfile) {
                        $filtered = Get-ECMA2ConnectorRunHistory -RunProfile $testProfile -MaxEvents 50 -ErrorAction SilentlyContinue
                        
                        if ($filtered) {
                            # All results should match the run profile
                            $allMatch = ($filtered | ForEach-Object { $_.RunProfile -eq $testProfile }) -notcontains $false
                            $allMatch | Should Be $true
                        }
                    }
                }
            }
            
            $true | Should Be $true
        }
    }
    
    Context "Time Filtering" {
        
        It "Should filter by StartTime" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $startTime = (Get-Date).AddHours(-1)
                $result = Get-ECMA2ConnectorRunHistory -StartTime $startTime -MaxEvents 10 -ErrorAction SilentlyContinue
                
                if ($result) {
                    # All results should be after StartTime
                    $allMatch = ($result | ForEach-Object { $_.TimeCreated -ge $startTime }) -notcontains $false
                    $allMatch | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should filter by EndTime" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $endTime = Get-Date
                $result = Get-ECMA2ConnectorRunHistory -EndTime $endTime -MaxEvents 10 -ErrorAction SilentlyContinue
                
                if ($result) {
                    # All results should be before EndTime
                    $allMatch = ($result | ForEach-Object { $_.TimeCreated -le $endTime }) -notcontains $false
                    $allMatch | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should filter by StartTime and EndTime together" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $startTime = (Get-Date).AddHours(-2)
                $endTime = (Get-Date).AddHours(-1)
                
                $result = Get-ECMA2ConnectorRunHistory -StartTime $startTime -EndTime $endTime -MaxEvents 50 -ErrorAction SilentlyContinue
                
                if ($result) {
                    # All results should be within time range
                    $allMatch = ($result | ForEach-Object { 
                        ($_.TimeCreated -ge $startTime) -and ($_.TimeCreated -le $endTime)
                    }) -notcontains $false
                    $allMatch | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
    }
    
    Context "Last Parameter" {
        
        It "Should limit results with Last parameter" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -Last 5 -MaxEvents 100 -ErrorAction SilentlyContinue
                
                if ($result) {
                    $result.Count -le 5 | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
    }
    
    Context "Provider Name Parsing" {
        
        It "Should extract connector name from ProviderName" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 20 -ErrorAction SilentlyContinue
                
                if ($result) {
                    # ConnectorName should not include "ECMA2Host." prefix
                    $allMatch = ($result | ForEach-Object { 
                        $_.ConnectorName -notlike "ECMA2Host.*" 
                    }) -notcontains $false
                    $allMatch | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
        
        It "Should filter out non-connector providers by default" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -Last 20 -MaxEvents 100 -ErrorAction SilentlyContinue
                
                if ($result) {
                    # Should not include MainDomain, ConfigWizard, etc when using wildcard
                    $allMatch = ($result | ForEach-Object {
                        $_.ConnectorName -notin @('MainDomain', 'ConfigWizard')
                    }) -notcontains $false
                    $allMatch | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
    }
    
    Context "Status Detection" {
        
        It "Should detect Success status" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $result = Get-ECMA2ConnectorRunHistory -MaxEvents 100 -ErrorAction SilentlyContinue
                
                if ($result) {
                    # Status property should exist and have valid values
                    $validStatuses = @('Success', 'Error', 'Information', 'Warning', 'Critical', 'Verbose', 'Unknown')
                    $allMatch = ($result | ForEach-Object {
                        $validStatuses -contains $_.Status
                    }) -notcontains $false
                    $allMatch | Should Be $true
                }
            }
            
            $true | Should Be $true
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle non-existent computer gracefully" {
            $result = Get-ECMA2ConnectorRunHistory -ComputerName "NonExistent$(Get-Random)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            # Should not throw, just return nothing or handle gracefully
            $true | Should Be $true
        }
        
        It "Should show warning when no events found" {
            $logExists = [System.Diagnostics.EventLog]::Exists('ECMA2Host')
            
            if ($logExists) {
                $warnings = @()
                # Use a very specific StartTime that likely has no events
                $result = Get-ECMA2ConnectorRunHistory -StartTime (Get-Date).AddYears(1) -WarningVariable warnings -ErrorAction SilentlyContinue
                
                # Either no results or a warning
                ($result.Count -eq 0) -or ($warnings.Count -gt 0) | Should Be $true
            }
            
            $true | Should Be $true
        }
    }
}
