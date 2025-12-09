$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$modulePath = Split-Path -Parent $here
$manifestPath = Join-Path $modulePath 'ECMA2HostTools.psd1'

# Import the module
Remove-Module ECMA2HostTools -ErrorAction SilentlyContinue
Import-Module $manifestPath -Force

Describe "Get-ECMA2ConnectorStatus" {
    
    # Setup test configuration file
    $testConfigPath = Join-Path $env:TEMP "ECMA2Test-Status-$(Get-Random).xml"
    $testXml = @'
<?xml version="1.0" encoding="utf-8"?>
<Configuration>
  <Connectors>
    <Connector>
      <ECMAConfig>
        <ECMAFolderPath>C:\Program Files\Microsoft ECMA2Host\Service\ECMA\Cache\TestConnector</ECMAFolderPath>
        <LibraryName>Microsoft.ECMA2Host.Extension</LibraryName>
        <AutosyncTimer>120</AutosyncTimer>
        <ProfileName>TestConnector</ProfileName>
        <ProfileDescription>Test Connector</ProfileDescription>
        <CreationDateTime>Monday, January 1, 2025 12:00:00 PM</CreationDateTime>
        <ModificationDateTime>Monday, January 1, 2025 12:00:00 PM</ModificationDateTime>
        <Validated>true</Validated>
      </ECMAConfig>
      <ConnectorConfig>
        <MAConfig>
          <parameter name="Username" type="String" use="Connectivity">testuser</parameter>
        </MAConfig>
        <RunProfiles>
          <RunProfile name="FullImport">
            <RunStep>
              <StepType>full-import</StepType>
            </RunStep>
          </RunProfile>
        </RunProfiles>
        <ObjectTypes>
          <ObjectType name="user" />
        </ObjectTypes>
      </ConnectorConfig>
    </Connector>
    <Connector>
      <ECMAConfig>
        <ECMAFolderPath>C:\Program Files\Microsoft ECMA2Host\Service\ECMA\Cache\IdleConnector</ECMAFolderPath>
        <LibraryName>Microsoft.ECMA2Host.Extension</LibraryName>
        <AutosyncTimer>0</AutosyncTimer>
        <ProfileName>IdleConnector</ProfileName>
        <ProfileDescription>Idle Test Connector</ProfileDescription>
        <CreationDateTime>Monday, January 1, 2025 12:00:00 PM</CreationDateTime>
        <ModificationDateTime>Monday, January 1, 2025 12:00:00 PM</ModificationDateTime>
        <Validated>false</Validated>
      </ECMAConfig>
      <ConnectorConfig>
        <MAConfig>
          <parameter name="Server" type="String" use="Connectivity">server01</parameter>
        </MAConfig>
        <RunProfiles>
          <RunProfile name="Export">
            <RunStep>
              <StepType>export</StepType>
            </RunStep>
          </RunProfile>
        </RunProfiles>
        <ObjectTypes>
          <ObjectType name="user" />
        </ObjectTypes>
      </ConnectorConfig>
    </Connector>
  </Connectors>
</Configuration>
'@

    Set-Content -Path $testConfigPath -Value $testXml
    
    Context "Parameter Validation" {
        
        It "Should accept Name parameter with wildcards" {
            $cmd = Get-Command Get-ECMA2ConnectorStatus
            $nameParam = $cmd.Parameters['Name']
            $nameParam.Attributes | Where-Object { $_.GetType().Name -eq 'SupportsWildcardsAttribute' } | Should Not BeNullOrEmpty
        }
        
        It "Should accept ConfigurationPath parameter" {
            $cmd = Get-Command Get-ECMA2ConnectorStatus
            $cmd.Parameters.Keys -contains 'ConfigurationPath' | Should Be $true
        }
        
        It "Should accept ComputerName parameter" {
            $cmd = Get-Command Get-ECMA2ConnectorStatus
            $cmd.Parameters.Keys -contains 'ComputerName' | Should Be $true
        }
        
        It "Should have ComputerName default to current computer" {
            $cmd = Get-Command Get-ECMA2ConnectorStatus
            $computerParam = $cmd.Parameters['ComputerName']
            $computerParam.Attributes | Where-Object { $_.GetType().Name -eq 'ParameterAttribute' } | ForEach-Object {
                $_.Mandatory | Should Be $false
            }
        }
        
        It "Should accept pipeline input for Name" {
            $connectorName = "TestConnector"
            $result = $connectorName | Get-ECMA2ConnectorStatus -ConfigurationPath $testConfigPath
            $result | Should Not BeNullOrEmpty
        }
    }
    
    Context "Connector Status Retrieval" {
        
        It "Should return status for all connectors by default" {
            $result = Get-ECMA2ConnectorStatus -Name "*" -ConfigurationPath $testConfigPath
            $result.Count | Should Be 2
        }
        
        It "Should filter connectors by name" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.Count | Should Be 1
            $result.Name | Should Be "TestConnector"
        }
        
        It "Should support wildcard filtering" {
            $result = Get-ECMA2ConnectorStatus -Name "Test*" -ConfigurationPath $testConfigPath
            $result.Count | Should Be 1
            $result.Name | Should Be "TestConnector"
        }
        
        It "Should return nothing when no connectors match filter" {
            $result = Get-ECMA2ConnectorStatus -Name "NonExistent" -ConfigurationPath $testConfigPath
            $result | Should BeNullOrEmpty
        }
    }
    
    Context "Status Object Properties" {
        
        It "Should return object with Name property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.Name | Should Be "TestConnector"
        }
        
        It "Should return object with Status property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.PSObject.Properties.Name -contains 'Status' | Should Be $true
            $result.Status | Should Not BeNullOrEmpty
        }
        
        It "Should return object with HealthStatus property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.PSObject.Properties.Name -contains 'HealthStatus' | Should Be $true
            $result.HealthStatus | Should Not BeNullOrEmpty
        }
        
        It "Should return object with AutosyncTimer property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.AutosyncTimer | Should Be 120
        }
        
        It "Should return object with AutosyncEnabled property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.PSObject.Properties.Name -contains 'AutosyncEnabled' | Should Be $true
            $result.AutosyncEnabled | Should Be $true
        }
        
        It "Should return object with ServiceStatus property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.PSObject.Properties.Name -contains 'ServiceStatus' | Should Be $true
            $result.ServiceStatus | Should Not BeNullOrEmpty
        }
        
        It "Should return object with Validated property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.Validated | Should Be $true
        }
        
        It "Should return object with IsInstalled property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.PSObject.Properties.Name -contains 'IsInstalled' | Should Be $true
        }
        
        It "Should return object with ECMAFolderPath property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.ECMAFolderPath | Should Be "C:\Program Files\Microsoft ECMA2Host\Service\ECMA\Cache\TestConnector"
        }
        
        It "Should return object with Description property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.Description | Should Be "Test Connector"
        }
        
        It "Should return object with RunProfiles property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.PSObject.Properties.Name -contains 'RunProfiles' | Should Be $true
            # RunProfiles should be an array (may be empty)
            $result.RunProfiles -is [array] | Should Be $true
        }
        
        It "Should return object with ComputerName property" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.ComputerName | Should Not BeNullOrEmpty
        }
    }
    
    Context "Autosync Status Detection" {
        
        It "Should detect autosync enabled when AutosyncTimer > 0" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.AutosyncEnabled | Should Be $true
            $result.AutosyncTimer | Should Be 120
        }
        
        It "Should detect autosync disabled when AutosyncTimer = 0" {
            $result = Get-ECMA2ConnectorStatus -Name "IdleConnector" -ConfigurationPath $testConfigPath
            $result.AutosyncEnabled | Should Be $false
            $result.AutosyncTimer | Should Be 0
        }
        
        It "Should show Idle status for manual connectors" {
            $result = Get-ECMA2ConnectorStatus -Name "IdleConnector" -ConfigurationPath $testConfigPath
            # Status depends on service state, but should be consistent
            $result.Status | Should Not BeNullOrEmpty
        }
    }
    
    Context "Service Status Integration" {
        
        It "Should query ECMA2Host service status" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.ServiceStatus | Should Not BeNullOrEmpty
        }
        
        It "Should reflect service status in connector status" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            # Status should mention service state if service is not running
            $serviceStatus = Get-ECMA2HostStatus
            $result.ServiceStatus | Should Be $serviceStatus.Status
        }
        
        It "Should set appropriate health status based on service state" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.HealthStatus | Should Not BeNullOrEmpty
            'Healthy', 'Paused', 'Unavailable', 'Warning', 'Unknown' -contains $result.HealthStatus | Should Be $true
        }
    }
    
    Context "Validation Status" {
        
        It "Should show validated status from configuration" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.Validated | Should Be $true
        }
        
        It "Should show unvalidated status when connector not validated" {
            $result = Get-ECMA2ConnectorStatus -Name "IdleConnector" -ConfigurationPath $testConfigPath
            $result.Validated | Should Be $false
        }
    }
    
    Context "Multiple Connectors" {
        
        It "Should return status for multiple connectors" {
            $result = Get-ECMA2ConnectorStatus -ConfigurationPath $testConfigPath
            $result.Count | Should Be 2
        }
        
        It "Should return different statuses for different connectors" {
            $results = Get-ECMA2ConnectorStatus -ConfigurationPath $testConfigPath
            $testConn = $results | Where-Object { $_.Name -eq 'TestConnector' }
            $idleConn = $results | Where-Object { $_.Name -eq 'IdleConnector' }
            
            $testConn.AutosyncEnabled | Should Be $true
            $idleConn.AutosyncEnabled | Should Be $false
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle missing configuration file gracefully" {
            $error.Clear()
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath "C:\NonExistent\Config.xml" -ErrorAction SilentlyContinue
            $error.Count -gt 0 | Should Be $true
        }
        
        It "Should show warning when no connectors found" {
            $warnings = @()
            Get-ECMA2ConnectorStatus -Name "NonExistent" -ConfigurationPath $testConfigPath -WarningVariable warnings
            $warnings.Count -gt 0 | Should Be $true
        }
        
        It "Should handle service query failures gracefully" {
            # Should still return connector info even if service query has issues
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result | Should Not BeNullOrEmpty
        }
    }
    
    Context "Installation Detection" {
        
        It "Should check if connector is installed locally" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            $result.PSObject.Properties.Name -contains 'IsInstalled' | Should Be $true
        }
        
        It "Should report installation status" {
            $result = Get-ECMA2ConnectorStatus -Name "TestConnector" -ConfigurationPath $testConfigPath
            # IsInstalled will be false for test paths that don't exist
            $result.IsInstalled -is [bool] | Should Be $true
        }
    }
}

# Cleanup
try {
    if ($testConfigPath -and (Test-Path $testConfigPath)) {
        Remove-Item $testConfigPath -Force -ErrorAction SilentlyContinue
    }
}
catch {
    # Ignore cleanup errors
}

# SIG # Begin signature block
# MIIoYgYJKoZIhvcNAQcCoIIoUzCCKE8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDiH36NPTC+DbyF
# 3Ymj408ciiz2fivlK0bzJJU7a/RzIKCCIV8wggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggawMIIEmKADAgECAhAIrUCyYNKcTJ9ezam9k67ZMA0GCSqG
# SIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRy
# dXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0zNjA0MjgyMzU5NTlaMGkx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEzODQg
# MjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDVtC9C0Cit
# eLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0JAfhS0/TeEP0F9ce2vnS
# 1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJrQ5qZ8sU7H/Lvy0daE6ZM
# swEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhFLqGfLOEYwhrMxe6TSXBC
# Mo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+FLEikVoQ11vkunKoAFdE3
# /hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh3K3kGKDYwSNHR7OhD26j
# q22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJwZPt4bRc4G/rJvmM1bL5
# OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQayg9Rc9hUZTO1i4F4z8ujo
# 7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbIYViY9XwCFjyDKK05huzU
# tw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchApQfDVxW0mdmgRQRNYmtwm
# KwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRroOBl8ZhzNeDhFMJlP/2NP
# TLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IBWTCCAVUwEgYDVR0TAQH/
# BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+YXsIiGX0TkIwHwYDVR0j
# BBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0
# cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8E
# PDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAEDMAgGBmeBDAEEATANBgkq
# hkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql+Eg08yy25nRm95RysQDK
# r2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFFUP2cvbaF4HZ+N3HLIvda
# qpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1hmYFW9snjdufE5BtfQ/g+
# lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3RywYFzzDaju4ImhvTnhOE7a
# brs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5UbdldAhQfQDN8A+KVssIhdXNS
# y0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw8MzK7/0pNVwfiThV9zeK
# iwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnPLqR0kq3bPKSchh/jwVYb
# KyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatEQOON8BUozu3xGFYHKi8Q
# xAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bnKD+sEq6lLyJsQfmCXBVm
# zGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQjiWQ1tygVQK+pKHJ6l/aCn
# HwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbqyK+p/pQd52MbOoZWeE4w
# gga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBH
# NDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1
# c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48RsAcrHXbo0Zo
# dLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi
# 6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNg
# xVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFiDNYiOTx4OtiF
# cMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZvkgFkriK9tUKJ
# m/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLeGkuAhHiGPMvS
# GmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1
# ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9
# MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36czwzsucuoKs7
# Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bG
# RinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6
# X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAd
# BgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJx
# XWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGln
# aWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJo
# dHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNy
# bDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQEL
# BQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxj
# aaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU/kXjjytJgnn0
# hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKChHyfpzee5kH0
# F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8dTXqvcnT
# mpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKf
# ZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qIijanrUR3anzE
# wlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbh
# OhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEBYTptMSbhdhGQDpOX
# gpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWsWCiKi9EO
# LLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wG
# WqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdcMIIG7TCCBNWg
# AwIBAgIQCoDvGEuN8QWC0cR2p5V0aDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0
# IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0Ex
# MB4XDTI1MDYwNDAwMDAwMFoXDTM2MDkwMzIzNTk1OVowYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBTSEEy
# NTYgUlNBNDA5NiBUaW1lc3RhbXAgUmVzcG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBANBGrC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3
# zBlCMGMyqJnfFNZx+wvA69HFTBdwbHwBSOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8Tch
# TySA2R4QKpVD7dvNZh6wW2R6kSu9RJt/4QhguSssp3qome7MrxVyfQO9sMx6ZAWj
# FDYOzDi8SOhPUWlLnh00Cll8pjrUcCV3K3E0zz09ldQ//nBZZREr4h/GI6Dxb2Uo
# yrN0ijtUDVHRXdmncOOMA3CoB/iUSROUINDT98oksouTMYFOnHoRh6+86Ltc5zjP
# KHW5KqCvpSduSwhwUmotuQhcg9tw2YD3w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KS
# uNLoZLc1Hf2JNMVL4Q1OpbybpMe46YceNA0LfNsnqcnpJeItK/DhKbPxTTuGoX7w
# JNdoRORVbPR1VVnDuSeHVZlc4seAO+6d2sC26/PQPdP51ho1zBp+xUIZkpSFA8vW
# doUoHLWnqWU3dCCyFG1roSrgHjSHlq8xymLnjCbSLZ49kPmk8iyyizNDIXj//cOg
# rY7rlRyTlaCCfw7aSUROwnu7zER6EaJ+AliL7ojTdS5PWPsWeupWs7NpChUk555K
# 096V1hE0yZIXe+giAwW00aHzrDchIc2bQhpp0IoKRR7YufAkprxMiXAJQ1XCmnCf
# gPf8+3mnAgMBAAGjggGVMIIBkTAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zy
# Me39/dfzkXFjGVBDz2GM6DAfBgNVHSMEGDAWgBTvb1NK6eQGfHrK4pBW9i/USezL
# TjAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsG
# AQUFBwEBBIGIMIGFMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wXQYIKwYBBQUHMAKGUWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNy
# dDBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5j
# cmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEB
# CwUAA4ICAQBlKq3xHCcEua5gQezRCESeY0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZ
# D9gBq9fNaNmFj6Eh8/YmRDfxT7C0k8FUFqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/
# ML9lFfim8/9yJmZSe2F8AQ/UdKFOtj7YMTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu
# +WUqW4daIqToXFE/JQ/EABgfZXLWU0ziTN6R3ygQBHMUBaB5bdrPbF6MRYs03h4o
# bEMnxYOX8VBRKe1uNnzQVTeLni2nHkX/QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2h
# ECZpqyU1d0IbX6Wq8/gVutDojBIFeRlqAcuEVT0cKsb+zJNEsuEB7O7/cuvTQasn
# M9AWcIQfVjnzrvwiCZ85EE8LUkqRhoS3Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol
# /DJgddJ35XTxfUlQ+8Hggt8l2Yv7roancJIFcbojBcxlRcGG0LIhp6GvReQGgMgY
# xQbV1S3CrWqZzBt1R9xJgKf47CdxVRd/ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3oc
# CVccAvlKV9jEnstrniLvUxxVZE/rptb7IRE2lskKPIJgbaP5t2nGj/ULLi49xTcB
# ZU8atufk+EMF/cWuiC7POGT75qaL6vdCvHlshtjdNXOCIUjsarfNZzCCB20wggVV
# oAMCAQICEAnI7Fw0fQcgWcyoNeinb/gwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENB
# MTAeFw0yMzAzMjkwMDAwMDBaFw0yNjA2MjIyMzU5NTlaMHUxCzAJBgNVBAYTAkFV
# MRgwFgYDVQQIEw9OZXcgU291dGggV2FsZXMxFDASBgNVBAcTC0NoZXJyeWJyb29r
# MRowGAYDVQQKExFEYXJyZW4gSiBSb2JpbnNvbjEaMBgGA1UEAxMRRGFycmVuIEog
# Um9iaW5zb24wggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDHrKfntVGe
# XaDp6S/nqZuiKuhmIqivGTXM9VwXuzO3gV8FcuLWD+QciGujTkWBLHpVViPV5jtT
# PnD0uo0TK6WW/cbVB/jaSmTvnkrYYEwLZxDtXVmgCumOwB/2VY5oDk1mVwVYm4wB
# PyUCiH2cseB5uRTh+oat27JQPkVEKaNzUMTb9gLs3JCkMG1uwKFyDbnY9HbmAog2
# LIZ//Zh884C9FaTWEaZoBGu1loHNSR9e1fkmJWn+qjFqWKFrjg8Lg5bUh9qee6gC
# Nv+Ceq1GBL57O0GfbICFHRpVK+fen6dGOI7sqclRhO0a9GvD7Qci1lLqcle2eZCj
# 6/zEY3q1wJgZ3+gHYSN5GOho89+en2ZDwOPVLgiFxYMk2U/OAKOipcPtEaie9CQ7
# eOPVJMu4XWvofIdj4lHX+610Gplee5mOufpRwJnOPlIE7lrJ6cJ07jZZG2cUZwsN
# g/lt6raNmgYQ3m3Iimc4r34gFpVn03B7QqcveoDOS/jgeOXsw6VOigB9YcEUozkV
# JVucqBU11Gz1AUX5VNztm2dMHQCXslGGh1gGsjaMhX7ina5gi7SMe9ujtOnc/SoP
# nCX/tWXSeynFL2YEdnfBdfRVeRtQlTJzs4TGUdnZyHieYdBIHDijR5d4TChXVUce
# JYVvLXK0EDeGU9hIBnyPXwXNItxl0xQNMQIDAQABo4ICAzCCAf8wHwYDVR0jBBgw
# FoAUaDfg67Y7+F8Rhvv+YXsIiGX0TkIwHQYDVR0OBBYEFAUxVql07mJzafndN3rN
# ijPSXRlIMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzCBtQYD
# VR0fBIGtMIGqMFOgUaBPhk1odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNybDBT
# oFGgT4ZNaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# Q29kZVNpZ25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcmwwPgYDVR0gBDcwNTAz
# BgZngQwBBAEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5jb20v
# Q1BTMIGUBggrBgEFBQcBAQSBhzCBhDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3Au
# ZGlnaWNlcnQuY29tMFwGCCsGAQUFBzAChlBodHRwOi8vY2FjZXJ0cy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQy
# MDIxQ0ExLmNydDAJBgNVHRMEAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBYQAlozzK3
# Gn8A32eZnv51K5L+MmICIud+XHXTwJv9rMBg07s0lQVRyDAafC1i5s1zwNRm8QTp
# gOC/L7w4IxKUBfSPT4eTDWIGIYNMUqQCKffygKHODkJ8JckRjzfgo2smONMcU8+P
# 4R6IVoOK5yTCLlRI5DLSpzHU26Z6lPOcO/AEJXw+/b/4FkNnS9U959fBzhI07fFU
# rq8ZBIUOSN0h/Aq/WIVL/eDm1iFGzilLeUhu5v3fstpn5CkUjpkZbi0qGCz1m8d+
# aQK7GJGj6Y3+WJeY4iT2NxkMxFP0kVVtK68AwG7SkjdIClrWcYozw27PGkFGAoox
# X43ujlhheEZ5j0kIdBX/AMsz0HMfS40P/Fu4FBC7BOiBblz+W49ouoHi8uuS0XuO
# kGZWA6v2zGs1KGUE5Y3v4bOqZDi+H9Sr+7WyWZjBDVVVESTZng0Xo7zZYh2mhhAL
# /4hdGaO6ar4+MAgghht4/7DUeVkkWJ8X+cUOK/YvYGapOMo8JPwyQltq5ijQlKMT
# SGVodhCJTEg88NwzCpNspWXYmPywIuRpmwshi7erE8/yBNcNTWMK6f8+r+CPdZQ4
# HV4Pn05IYcbeO4VpozDg92WFUhc0JoPGpdYkP/ukWCoH7MMOuLSJMvCTjmV/97LP
# 7ocSlIzycWCZDsEMFMqAGM43LvwBOwctKzGCBlkwggZVAgEBMH0waTELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENB
# MQIQCcjsXDR9ByBZzKg16Kdv+DANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3
# AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCB01SJcA4d/
# TlVMqrVhmSACHt9nn8po6UeRRX12mK1D8DANBgkqhkiG9w0BAQEFAASCAgBlr+dp
# jOR2P0pYVhPuj9rA16cIe6D7H7clFZmpGrnQ97VljIzenMEb4aHJ8CdHarM5B/BT
# J/NwHQ3iStVQDM0aVnMcQOsj4Y6eGFEXZ4bG/cFWTOVDfcE3BJn9r3Efd8+pO9UR
# lVSKI2U7yYAcl95gRT/WCXpE4ttmy/ui+EMussUftn8xQ3SfJBMvmGodGKmsO2gy
# DmWPSMD2KziydOyfnkgm940zU7mjD3xqWaLtA5X9x+x7uyLojH3zeFOkPEJagFRP
# u+SNAtKKDTNT4+004uaf6H1uZNGyKr6f1iJ3ha++XKyoLvxuyDEW7hNWQ/XqwUCS
# 3VbiVeMhheUvAQinhiUcDJvrQl6ABQvpgzCRGwtMExRY/g48eWJ6tW4dayd0Zht5
# 8PQkB72qc+n+KHWNistmR8dvrUoGCzK4kwiGeWJ09z+GLlyjRSWDViewOz+vfk0M
# SuonnzRla3kXnBBtezGLcoDgURnsvV2w2rMIq9X4FGgmh/AVWDI71cTP24Bb4Orv
# rHJVg2YcRoov1Ywg7BGpUAUjFplnwmJ8FTtXY1vlJ0MNheio30d7cQtPKyLivnxW
# vhuAsMkBbU39KDAdFjdwvsrW8OzpWS/vB9tbPBJ65z83oiPBq70lgvTONds1fiQg
# cxkLsWlfENIxG8HGJwuJw8BAgJr4Xu4BJjvGwKGCAyYwggMiBgkqhkiG9w0BCQYx
# ggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcg
# UlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZI
# AWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJ
# BTEPFw0yNTEyMDkwMTEyNTFaMC8GCSqGSIb3DQEJBDEiBCBqBw2Qq5znisYpJih/
# ZoT2t2lu2lEbgvMNy9YtQKnnuDANBgkqhkiG9w0BAQEFAASCAgCbbXKyCc+zT/2/
# zSuQz3u0+XF+GHdBs515DeYfdgrg+0ufuYuB9PFvR/dUnEl2Ujc17HR2KIlJxFH8
# yGnEtQj/I7gkRF0+ywE1queMY5PtJhw80OXX8BVocWhrfvW0tqVB/QSlInY/5Pl4
# hNvU/w/l6HXK+f0UeE3mdUFbPxNEioRPw2jUAIBAJf+Upy6/m9nZ68mJckP+IBfT
# urNJdEm/BDMOmC3aQjTyR1SEq3qlbUc2/DuvP22F52zaeYipL72Pg/HZHwzanfa1
# IV99RBb9Hwqcfo8GSz/A3+KUcYdoM4j6nH39KgM7Bk/J58vHcQIsPq4cLHnRfxg2
# bFxebQpcVepD7lk92MBKNkcitXdjBnFH1AaGVZMjcRi9LbCcYq7EwV/CGvBLSuKw
# OC1Xc3b0OEzthibKsCPtj4vsPdySD1upPufrnzweJ2/padRG/rbS4QU6pX1i8tFz
# PccL3rM7ObMlKn+MiXM6HsK/BuEPtsrrIsSnQI8idSFq3aFB/N4I6tnW6Ebzhdtc
# KuQitjqDC/Us/a1YJNz3TjrkjHYRjX89jqDT6frNYbqKz0abE4GaiCxzqBBbczDC
# znUha3/rmkAkvgN8fZ+Ujb6AJd+E1Rj4DH2N0fuXzWIk/6qQUuuUixN9KqUPbR2P
# MY9d8pKVR8S2vZkhrNMzl/2ITDnDrA==
# SIG # End signature block
