# Import the module
$ModulePath = Split-Path -Parent $PSScriptRoot
Import-Module "$ModulePath\ECMA2HostTools.psd1" -Force

Describe 'New-ECMA2ConnectorDocumentation' {
    
    BeforeEach {
        # Create a temporary test configuration
        $script:TestConfigPath = Join-Path $env:TEMP "TestConfig_$(Get-Random).xml"
        $script:TestOutputPath = Join-Path $env:TEMP "TestDoc_$(Get-Random).md"
        
        $xmlContent = @'
<?xml version="1.0"?>
<Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Connectors>
    <Connector>
      <ECMAConfig>
        <ECMAFolderPath>C:\Program Files\Microsoft ECMA2Host\Service\ECMA\Cache\TestConnector</ECMAFolderPath>
        <LibraryName>Microsoft.ECMA2Host.Extension</LibraryName>
        <AutosyncTimer>120</AutosyncTimer>
        <ProfileName>TestConnector</ProfileName>
        <ProfileDescription>Test Connector Description</ProfileDescription>
        <CreationDateTime>Monday, January 1, 2025 12:00:00 PM</CreationDateTime>
        <ModificationDateTime>Monday, January 1, 2025 12:00:00 PM</ModificationDateTime>
        <Validated>true</Validated>
      </ECMAConfig>
      <ConnectorConfig>
        <Parameters>
          <Parameter>
            <Name>Username</Name>
            <Type>String</Type>
            <Use>Connectivity</Use>
            <SchemaNumber>1</SchemaNumber>
            <Encrypted>false</Encrypted>
            <Value>testuser</Value>
          </Parameter>
          <Parameter>
            <Name>Password</Name>
            <Type>EncryptedString</Type>
            <Use>Connectivity</Use>
            <SchemaNumber>1</SchemaNumber>
            <Encrypted>true</Encrypted>
            <Value>encrypted_value_here</Value>
          </Parameter>
          <Parameter>
            <Name>Schema Script</Name>
            <Type>String</Type>
            <Use>Connectivity</Use>
            <SchemaNumber>1</SchemaNumber>
            <Encrypted>false</Encrypted>
            <Value>C:\Scripts\schema.ps1</Value>
          </Parameter>
        </Parameters>
        <RunConfigurations>
          <RunConfiguration>
            <Name>FullImport</Name>
          </RunConfiguration>
          <RunConfiguration>
            <Name>DeltaImport</Name>
          </RunConfiguration>
          <RunConfiguration>
            <Name>Export</Name>
          </RunConfiguration>
        </RunConfigurations>
        <IsExportSupported>true</IsExportSupported>
        <IsFullImportSupported>true</IsFullImportSupported>
        <IsDeltaImportSupported>true</IsDeltaImportSupported>
        <IsExportOnly>false</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema>
          <EntrySchema>
            <ObjectType>user</ObjectType>
          </EntrySchema>
          <EntrySchema>
            <ObjectType>group</ObjectType>
          </EntrySchema>
        </EntriesSchema>
      </Schema>
    </Connector>
    <Connector>
      <ECMAConfig>
        <ECMAFolderPath>C:\Program Files\Microsoft ECMA2Host\Service\ECMA\Cache\SecondConnector</ECMAFolderPath>
        <LibraryName>Microsoft.ECMA2Host.Extension</LibraryName>
        <AutosyncTimer>60</AutosyncTimer>
        <ProfileName>SecondConnector</ProfileName>
        <ProfileDescription>Second Test Connector</ProfileDescription>
        <CreationDateTime>Tuesday, January 2, 2025 12:00:00 PM</CreationDateTime>
        <ModificationDateTime>Tuesday, January 2, 2025 12:00:00 PM</ModificationDateTime>
        <Validated>false</Validated>
      </ECMAConfig>
      <ConnectorConfig>
        <Parameters>
          <Parameter>
            <Name>ApiKey</Name>
            <Type>String</Type>
            <Use>Connectivity</Use>
            <SchemaNumber>1</SchemaNumber>
            <Encrypted>false</Encrypted>
            <Value>test-api-key</Value>
          </Parameter>
        </Parameters>
        <RunConfigurations>
          <RunConfiguration>
            <Name>Export</Name>
          </RunConfiguration>
        </RunConfigurations>
        <IsExportSupported>true</IsExportSupported>
        <IsFullImportSupported>false</IsFullImportSupported>
        <IsDeltaImportSupported>false</IsDeltaImportSupported>
        <IsExportOnly>true</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema>
          <EntrySchema>
            <ObjectType>person</ObjectType>
          </EntrySchema>
        </EntriesSchema>
      </Schema>
    </Connector>
  </Connectors>
</Configuration>
'@
        Set-Content -Path $script:TestConfigPath -Value $xmlContent
    }

    AfterEach {
        if (Test-Path $script:TestConfigPath) {
            Remove-Item -Path $script:TestConfigPath -Force
        }
        if (Test-Path $script:TestOutputPath) {
            Remove-Item -Path $script:TestOutputPath -Force
        }
    }

    Context 'Parameter Validation' {
        
        It 'Should accept ConnectorName parameter' {
            $command = Get-Command New-ECMA2ConnectorDocumentation
            $command.Parameters.ContainsKey('ConnectorName') | Should Be $true
        }

        It 'Should accept Path parameter' {
            $command = Get-Command New-ECMA2ConnectorDocumentation
            $command.Parameters.ContainsKey('Path') | Should Be $true
        }

        It 'Should accept ConfigurationPath parameter' {
            $command = Get-Command New-ECMA2ConnectorDocumentation
            $command.Parameters.ContainsKey('ConfigurationPath') | Should Be $true
        }

        It 'Should accept IncludeParameters parameter with default true' {
            $command = Get-Command New-ECMA2ConnectorDocumentation
            $command.Parameters.ContainsKey('IncludeParameters') | Should Be $true
        }

        It 'Should accept IncludeSecrets switch parameter' {
            $command = Get-Command New-ECMA2ConnectorDocumentation
            $command.Parameters.ContainsKey('IncludeSecrets') | Should Be $true
        }

        It 'Should accept InputObject from pipeline' {
            $command = Get-Command New-ECMA2ConnectorDocumentation
            ($command.Parameters['InputObject'].Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }).ValueFromPipeline | Should Be $true
        }

        It 'Should support wildcards for ConnectorName' {
            $command = Get-Command New-ECMA2ConnectorDocumentation
            ($command.Parameters['ConnectorName'].Attributes | Where-Object { $_.TypeId.Name -eq 'SupportsWildcardsAttribute' }) | Should Not BeNullOrEmpty
        }
    }

    Context 'Documentation Generation from Name' {
        
        It 'Should generate documentation for single connector' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result | Should Not BeNullOrEmpty
            $result -match '# ECMA2Host Connector Documentation' | Should Be $true
            $result -match '## TestConnector' | Should Be $true
        }

        It 'Should save documentation to file' {
            New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -Path $script:TestOutputPath
            
            Test-Path $script:TestOutputPath | Should Be $true
            $content = Get-Content -Path $script:TestOutputPath -Raw
            $content -match 'TestConnector' | Should Be $true
        }

        It 'Should generate documentation for multiple connectors' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "*" -ConfigurationPath $script:TestConfigPath
            
            $result -match 'TestConnector' | Should Be $true
            $result -match 'SecondConnector' | Should Be $true
            $result -match '## Table of Contents' | Should Be $true
        }

        It 'Should support wildcard filtering' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "Test*" -ConfigurationPath $script:TestConfigPath
            
            $result -match 'TestConnector' | Should Be $true
            $result -match 'SecondConnector' | Should Be $false
        }

        It 'Should handle connector not found gracefully' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "NonExistent" -ConfigurationPath $script:TestConfigPath -WarningAction SilentlyContinue
            
            $result | Should BeNullOrEmpty
        }
    }

    Context 'Documentation Generation from Pipeline' {
        
        It 'Should accept connector from pipeline' {
            $connector = Get-ECMA2Connector -Name "TestConnector" -ConfigurationPath $script:TestConfigPath
            $result = $connector | New-ECMA2ConnectorDocumentation
            
            $result | Should Not BeNullOrEmpty
            $result -match 'TestConnector' | Should Be $true
        }

        It 'Should accept multiple connectors from pipeline' {
            $connectors = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath
            $result = $connectors | New-ECMA2ConnectorDocumentation
            
            $result -match 'TestConnector' | Should Be $true
            $result -match 'SecondConnector' | Should Be $true
        }

        It 'Should save piped connectors to file' {
            Get-ECMA2Connector -Name "TestConnector" -ConfigurationPath $script:TestConfigPath | 
                New-ECMA2ConnectorDocumentation -Path $script:TestOutputPath
            
            Test-Path $script:TestOutputPath | Should Be $true
        }
    }

    Context 'Documentation Content - Overview Section' {
        
        It 'Should include connector name in overview' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '\| \*\*Name\*\* \| TestConnector \|' | Should Be $true
        }

        It 'Should include description in overview' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match 'Test Connector Description' | Should Be $true
        }

        It 'Should include library name in overview' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match 'Microsoft.ECMA2Host.Extension' | Should Be $true
        }

        It 'Should include autosync timer in overview' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '\| \*\*Autosync Timer\*\* \| 120 minutes \|' | Should Be $true
        }

        It 'Should include validated status in overview' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '\| \*\*Validated\*\* \| True \|' | Should Be $true
        }

        It 'Should include timestamps in overview' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match 'Monday, January 1, 2025' | Should Be $true
        }
    }

    Context 'Documentation Content - Capabilities Section' {
        
        It 'Should include capabilities table' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '### Capabilities' | Should Be $true
            $result -match '\| \*\*Export\*\* \|' | Should Be $true
            $result -match '\| \*\*Full Import\*\* \|' | Should Be $true
            $result -match '\| \*\*Delta Import\*\* \|' | Should Be $true
        }

        It 'Should show correct capability values' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '\| \*\*Export\*\* \| True \|' | Should Be $true
            $result -match '\| \*\*Full Import\*\* \| True \|' | Should Be $true
            $result -match '\| \*\*Export Only\*\* \| False \|' | Should Be $true
        }
    }

    Context 'Documentation Content - Run Profiles Section' {
        
        It 'Should include run profiles section' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '### Run Profiles' | Should Be $true
        }

        It 'Should list all run profiles' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '- FullImport' | Should Be $true
            $result -match '- DeltaImport' | Should Be $true
            $result -match '- Export' | Should Be $true
        }
    }

    Context 'Documentation Content - Object Types Section' {
        
        It 'Should include object types section' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '### Object Types' | Should Be $true
        }

        It 'Should list all object types' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '- `user`' | Should Be $true
            $result -match '- `group`' | Should Be $true
        }
    }

    Context 'Documentation Content - Parameters Section' {
        
        It 'Should include parameters section when IncludeParameters is true' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -IncludeParameters $true
            
            $result -match '### Parameters' | Should Be $true
        }

        It 'Should not include parameters section when IncludeParameters is false' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -IncludeParameters $false
            
            $result -match '### Parameters' | Should Be $false
        }

        It 'Should list parameter details in table format' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '\| Name \| Type \| Use \| Value \| Encrypted \|' | Should Be $true
            $result -match '\| Username \| String \| Connectivity \|' | Should Be $true
            $result -match '\| Password \|' | Should Be $true
        }

        It 'Should show encrypted placeholder for encrypted parameters' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -IncludeSecrets:$false
            
            # Check that Password parameter appears with ENCRYPTED placeholder
            ($result -match 'Password') -and ($result -match 'ENCRYPTED') -and ($result -match 'EncryptedString') | Should Be $true
        }

        It 'Should sort parameters alphabetically' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            # Password should come before Schema Script and Username
            $passwordIndex = $result.IndexOf('| Password |')
            $schemaIndex = $result.IndexOf('| Schema Script |')
            $usernameIndex = $result.IndexOf('| Username |')
            
            $passwordIndex -lt $schemaIndex | Should Be $true
            $schemaIndex -lt $usernameIndex | Should Be $true
        }
    }

    Context 'Return Object' {
        
        It 'Should return summary object when Path is specified' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -Path $script:TestOutputPath
            
            $result.PSObject.TypeNames -contains 'ECMA2Host.DocumentationGenerated' | Should Be $true
        }

        It 'Should include Path in summary' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -Path $script:TestOutputPath
            
            $result.Path | Should Be $script:TestOutputPath
        }

        It 'Should include ConnectorCount in summary' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -Path $script:TestOutputPath
            
            $result.ConnectorCount | Should Be 1
        }

        It 'Should include correct ConnectorCount for multiple connectors' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "*" -ConfigurationPath $script:TestConfigPath -Path $script:TestOutputPath
            
            $result.ConnectorCount | Should Be 2
        }

        It 'Should include GeneratedDate in summary' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -Path $script:TestOutputPath
            
            $result.GeneratedDate | Should Not BeNullOrEmpty
            $result.GeneratedDate.GetType().Name | Should Be 'DateTime'
        }

        It 'Should include IncludedSecrets flag in summary' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -Path $script:TestOutputPath -IncludeSecrets
            
            $result.IncludedSecrets | Should Be $true
        }
    }

    Context 'Multiple Connectors Documentation' {
        
        It 'Should include table of contents for multiple connectors' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "*" -ConfigurationPath $script:TestConfigPath
            
            $result -match '## Table of Contents' | Should Be $true
            $result -match '\[TestConnector\]' | Should Be $true
            $result -match '\[SecondConnector\]' | Should Be $true
        }

        It 'Should include separator between connectors' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "*" -ConfigurationPath $script:TestConfigPath
            
            # Should have separator between two connectors
            $separators = ([regex]::Matches($result, '---')).Count
            $separators -ge 2 | Should Be $true
        }

        It 'Should document all connectors completely' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "*" -ConfigurationPath $script:TestConfigPath
            
            # TestConnector checks
            $result -match '## TestConnector' | Should Be $true
            $result -match 'Test Connector Description' | Should Be $true
            
            # SecondConnector checks
            $result -match '## SecondConnector' | Should Be $true
            $result -match 'Second Test Connector' | Should Be $true
        }
    }

    Context 'Footer and Metadata' {
        
        It 'Should include generation timestamp' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '\*\*Generated:\*\*' | Should Be $true
        }

        It 'Should include generated by username' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '\*\*Generated By:\*\*' | Should Be $true
            $result -match $env:USERNAME | Should Be $true
        }

        It 'Should include computer name' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match '\*\*Computer:\*\*' | Should Be $true
            $result -match $env:COMPUTERNAME | Should Be $true
        }

        It 'Should include footer with module attribution' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath
            
            $result -match 'Generated by ECMA2HostTools PowerShell Module' | Should Be $true
        }
    }

    Context 'File Output' {
        
        It 'Should create output directory if it does not exist' {
            $newDir = Join-Path $env:TEMP "NewDocDir_$(Get-Random)"
            $newPath = Join-Path $newDir "test.md"
            
            try {
                New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -Path $newPath
                
                Test-Path $newPath | Should Be $true
            }
            finally {
                if (Test-Path $newDir) {
                    Remove-Item -Path $newDir -Recurse -Force
                }
            }
        }

        It 'Should save valid markdown content' {
            New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath $script:TestConfigPath -Path $script:TestOutputPath
            
            $content = Get-Content -Path $script:TestOutputPath -Raw
            $content | Should Not BeNullOrEmpty
            $content -match '# ECMA2Host Connector Documentation' | Should Be $true
        }
    }

    Context 'Error Handling' {
        
        It 'Should handle invalid configuration path gracefully' {
            $result = New-ECMA2ConnectorDocumentation -ConnectorName "TestConnector" -ConfigurationPath "C:\NonExistent\Config.xml" -ErrorAction SilentlyContinue
            
            $result | Should BeNullOrEmpty
        }

        It 'Should show warning when no connectors found' {
            $warnings = @()
            New-ECMA2ConnectorDocumentation -ConnectorName "NonExistent" -ConfigurationPath $script:TestConfigPath -WarningVariable warnings -WarningAction SilentlyContinue
            
            $warnings.Count -gt 0 | Should Be $true
            $warnings[0] -match 'No connectors found' | Should Be $true
        }
    }
}

# SIG # Begin signature block
# MIIoYgYJKoZIhvcNAQcCoIIoUzCCKE8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBwv4PTF2NTPUm6
# WFL/vlOfBfqX4ccaaxhkvga4aHX8wKCCIV8wggWNMIIEdaADAgECAhAOmxiO+dAt
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
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCXGnfeEROs
# knXvfrPngDLQ3U+nK5HD1arpc+qrEvtjOzANBgkqhkiG9w0BAQEFAASCAgCxJDdc
# MeyI4CPcWuZtVDeFOwIEeUIrVvok5ZcKyI2yDS411zZvie7eKgg8btNIMwSVtnMH
# FQ3wmxKzYAVdMWeYEK0+5t7qXg+cEHGKRzH+irEJ3KsBAtaQ/9+CpmH76OvFEriG
# mKKdop+saeHNuIJqjG6ibXImmIyrao86DvJQTAf6zFHUeA+JFKFEgAZGRPTfbtsD
# xrlxlv3B0chmPlTMX+SrYcLFGt1VId/kQlb8s8+wqFEIm41GoPlQBLqX68pgLoFO
# GJ6E3CseQIp5BbDBZxuKFN/gRglKRRK909KzLbaohqMAFctS9PrEB4AIEYju91uY
# aYIiVznY1GO5WMJtkzGSrSgqGlvtszD1xVzg3T9ssGUb9vyug3xpf95reEvUlPDX
# Tlv2ieXG5kL2fbJv2xTPNgyPxg3AJocLWezr5ICoZDSXI/V9klF6RNCdCcprk1oQ
# olf2W8ImFqCaVZhKB/KGO9DBD319m+PbL1L4JH3yUXY4HwEtLz8qPQhh270dJHBd
# KT1lbZb4TfA8UdYlxKB4HHo0pWFg7AX4L3rv7169KZYYgLqJvUvQ4X2zy2TvamIF
# BbkAV0UxPFb3DrdaeMx+BF9+xoHwX06W8lCFy3eug5AFsGGZnSNJ9kvSzIj03m4j
# wjxrQQe90l44LYd91LzkporJGnSW0Vk3iIvAt6GCAyYwggMiBgkqhkiG9w0BCQYx
# ggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcg
# UlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZI
# AWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJ
# BTEPFw0yNTEyMDkwMTEyNTJaMC8GCSqGSIb3DQEJBDEiBCB0aTLyErpJTmhIlCFJ
# sLUddp5v52NPle9CaOmy3gifRjANBgkqhkiG9w0BAQEFAASCAgCRequiO5WWEPjv
# hWspJo/nzUccZ1ZKorjAS+ohMNatOAJrmylC72cTHqIh2wxff5hw/0RFKhHCIrc6
# /qAQbpfoX8hZGwOVpVH9PcGdWRkYj5UsNBXSwRcSKT+wZbaeV8EwKv2ToOoBbM2q
# VrRvLzDTBpAvLeywKNqTI/yHiedtxdQkGYL8F3IjRGvcWY85uFqLQF2oEElZNOtg
# bVVzwU5wxIjatVnV658J5pGYf0Y8Bl4e/wlaRdBTnnIrtyCr0T/4MS6Qs3cJ1Mht
# QyjUgOa4VkzC5V63icHapjPdgqVp/dAt8n34yzX4tCCnE18cu8qdiGxKkxZFEcb5
# /lZhSW/ntcuNqpv0yer8yDwc7Elg4imUoBs/eVJu5VBt2i8yQXFDgpNzm8Uyi9/5
# rzzVclxJR0ue6Dzn5Y401XugH1z828gbYU+nfT5PjQ6d7g4Uimor3uz6UlxzcTXU
# m63UwI8dLTa0dihbqo7hau98WQ5fSDySIJQBdbBYW0J16DzJbItlKS6mCGPWy8yO
# d2JKFFo6wn6OchpbnxgKHT/wSqTeY/JaXWOZmKDUAOPfcAnVb9K5DS51KR+Qr0o8
# ow+/T5tKrWYxhahn/UnH4FvVIZx+AA4SIc6p7IV5+2TELS/csFnz3S2Aek99qZ5m
# lImjFxDeAg96gjeE38sgwfRgI7cJNw==
# SIG # End signature block
