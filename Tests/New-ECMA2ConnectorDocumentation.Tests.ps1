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
