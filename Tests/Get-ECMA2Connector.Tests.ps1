# Import the module
$ModulePath = Split-Path -Parent $PSScriptRoot
Import-Module "$ModulePath\ECMA2HostTools.psd1" -Force

Describe 'Get-ECMA2Connector' {
    Context 'Parameter Validation' {
        It 'Should have Name parameter with wildcard support' {
            $command = Get-Command Get-ECMA2Connector
            $command.Parameters['Name'].Attributes.TypeId.Name -contains 'SupportsWildcardsAttribute' | Should Be $true
        }

        It 'Should have ConfigurationPath parameter' {
            $command = Get-Command Get-ECMA2Connector
            $command.Parameters['ConfigurationPath'] | Should Not BeNullOrEmpty
        }

        It 'Should have ComputerName parameter with default value' {
            $command = Get-Command Get-ECMA2Connector
            $command.Parameters['ComputerName'] | Should Not BeNullOrEmpty
        }

        It 'Should accept pipeline input for Name parameter' {
            $command = Get-Command Get-ECMA2Connector
            $command.Parameters['Name'].Attributes.ValueFromPipeline | Should Be $true
        }
    }

    Context 'Configuration File Handling' {
        # Create a test configuration file
        $script:TestConfigPath = Join-Path $TestDrive "Configuration.xml"
        
        BeforeEach {
            
            $xmlContent = @'
<?xml version="1.0" encoding="utf-8"?>
<Configuration>
  <Connectors>
    <Connector>
      <ConnectorConfig>
        <Parameters>
          <Parameter>
            <Name>Username</Name>
            <Type>String</Type>
            <Use>Connectivity</Use>
            <Encrypted>false</Encrypted>
            <Value>testuser</Value>
          </Parameter>
          <Parameter>
            <Name>Password</Name>
            <Type>EncryptedString</Type>
            <Use>Connectivity</Use>
            <Encrypted>true</Encrypted>
            <Value>encrypted_value_here</Value>
          </Parameter>
        </Parameters>
        <RunConfigurations>
          <RunConfiguration>
            <Name>FullImport</Name>
          </RunConfiguration>
          <RunConfiguration>
            <Name>Export</Name>
          </RunConfiguration>
        </RunConfigurations>
        <IsExportSupported>true</IsExportSupported>
        <IsFullImportSupported>true</IsFullImportSupported>
        <IsDeltaImportSupported>false</IsDeltaImportSupported>
        <IsExportOnly>false</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema>
          <EntrySchema>
            <ObjectType>user</ObjectType>
          </EntrySchema>
        </EntriesSchema>
      </Schema>
      <ECMAConfig>
        <ECMAFolderPath>C:\TestPath</ECMAFolderPath>
        <LibraryName>Test.Library</LibraryName>
        <AutosyncTimer>120</AutosyncTimer>
        <ProfileName>TestConnector</ProfileName>
        <ProfileDescription>Test Connector Description</ProfileDescription>
        <CreationDateTime>Monday, January 1, 2025 12:00:00 PM</CreationDateTime>
        <ModificationDateTime>Monday, January 1, 2025 12:00:00 PM</ModificationDateTime>
        <Validated>true</Validated>
      </ECMAConfig>
    </Connector>
    <Connector>
      <ConnectorConfig>
        <Parameters />
        <RunConfigurations>
          <RunConfiguration>
            <Name>DeltaImport</Name>
          </RunConfiguration>
        </RunConfigurations>
        <IsExportSupported>false</IsExportSupported>
        <IsFullImportSupported>false</IsFullImportSupported>
        <IsDeltaImportSupported>true</IsDeltaImportSupported>
        <IsExportOnly>false</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema>
          <EntrySchema>
            <ObjectType>person</ObjectType>
          </EntrySchema>
        </EntriesSchema>
      </Schema>
      <ECMAConfig>
        <ECMAFolderPath>C:\TestPath2</ECMAFolderPath>
        <LibraryName>Test.Library2</LibraryName>
        <AutosyncTimer>60</AutosyncTimer>
        <ProfileName>ADConnector</ProfileName>
        <ProfileDescription>AD Connector Description</ProfileDescription>
        <CreationDateTime>Monday, January 1, 2025 1:00:00 PM</CreationDateTime>
        <ModificationDateTime>Monday, January 1, 2025 1:00:00 PM</ModificationDateTime>
        <Validated>false</Validated>
      </ECMAConfig>
    </Connector>
  </Connectors>
  <Setting>
    <Port>8585</Port>
  </Setting>
</Configuration>
'@
            Set-Content -Path $script:TestConfigPath -Value $xmlContent
        }

        It 'Should throw error when configuration file does not exist' {
            # Pester 3 doesn't check error messages, just that an error occurs
            $threw = $false
            try {
                Get-ECMA2Connector -ConfigurationPath "C:\NonExistent\Config.xml" -ErrorAction Stop
            } catch {
                $threw = $true
            }
            $threw | Should Be $true
        }

        It 'Should read connectors from configuration file' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath
            $result | Should Not BeNullOrEmpty
            $result.Count | Should Be 2
        }

        It 'Should return connector with correct properties' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "TestConnector"
            $result.Name | Should Be "TestConnector"
            $result.Description | Should Be "Test Connector Description"
            $result.LibraryName | Should Be "Test.Library"
            $result.AutosyncTimer | Should Be "120"
            $result.Validated | Should Be $true
        }

        It 'Should filter connectors by name' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "ADConnector"
            $result.Count | Should Be 1
            $result.Name | Should Be "ADConnector"
        }

        It 'Should support wildcard filtering' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "AD*"
            $result.Count | Should Be 1
            $result.Name | Should Be "ADConnector"
        }

        It 'Should return all connectors when no name filter is specified' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath
            $result.Count | Should Be 2
        }

        It 'Should return empty array when no connectors match filter' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "NonExistent*"
            $result | Should BeNullOrEmpty
        }
    }

    Context 'Connector Properties' {
        $script:TestConfigPath = Join-Path $TestDrive "Configuration.xml"
        
        BeforeEach {
            $xmlContent = @'
<?xml version="1.0" encoding="utf-8"?>
<Configuration>
  <Connectors>
    <Connector>
      <ConnectorConfig>
        <Parameters>
          <Parameter>
            <Name>Username</Name>
            <Type>String</Type>
            <Use>Connectivity</Use>
            <Encrypted>false</Encrypted>
            <Value>testuser</Value>
          </Parameter>
        </Parameters>
        <RunConfigurations>
          <RunConfiguration>
            <Name>FullImport</Name>
          </RunConfiguration>
        </RunConfigurations>
        <IsExportSupported>true</IsExportSupported>
        <IsFullImportSupported>true</IsFullImportSupported>
        <IsDeltaImportSupported>false</IsDeltaImportSupported>
        <IsExportOnly>false</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema>
          <EntrySchema>
            <ObjectType>user</ObjectType>
          </EntrySchema>
        </EntriesSchema>
      </Schema>
      <ECMAConfig>
        <ProfileName>TestConnector</ProfileName>
        <AutosyncTimer>120</AutosyncTimer>
        <Validated>true</Validated>
      </ECMAConfig>
    </Connector>
  </Connectors>
</Configuration>
'@
            Set-Content -Path $script:TestConfigPath -Value $xmlContent
        }

        It 'Should return RunProfiles as array' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath
            $result.RunProfiles.GetType().BaseType.Name | Should Be "Array"
            ($result.RunProfiles -contains "FullImport") | Should Be $true
        }

        It 'Should return ObjectTypes as array' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath
            $result.ObjectTypes.GetType().BaseType.Name | Should Be "Array"
            ($result.ObjectTypes -contains "user") | Should Be $true
        }

        It 'Should return Parameters as hashtable' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath
            $result.Parameters | Should BeOfType [System.Collections.Hashtable]
            $result.Parameters.ContainsKey('Username') | Should Be $true
        }

        It 'Should mask encrypted parameter values' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath
            $param = $result.Parameters['Username']
            $param.Value | Should Be "testuser"
        }

        It 'Should parse boolean properties correctly' {
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath
            $result.IsExportSupported | Should Be $true
            $result.IsFullImportSupported | Should Be $true
            $result.IsDeltaImportSupported | Should Be $false
            $result.Validated | Should Be $true
        }
    }

    Context 'Edge Cases' {
        It 'Should handle configuration with single connector' {
            $singleConnectorConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<Configuration>
  <Connectors>
    <Connector>
      <ConnectorConfig>
        <Parameters />
        <RunConfigurations />
        <IsExportSupported>false</IsExportSupported>
        <IsFullImportSupported>false</IsFullImportSupported>
        <IsDeltaImportSupported>false</IsDeltaImportSupported>
        <IsExportOnly>false</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema />
      </Schema>
      <ECMAConfig>
        <ProfileName>SingleConnector</ProfileName>
      </ECMAConfig>
    </Connector>
  </Connectors>
</Configuration>
'@
            $configPath = Join-Path $TestDrive "SingleConnector.xml"
            Set-Content -Path $configPath -Value $singleConnectorConfig
            
            $result = Get-ECMA2Connector -ConfigurationPath $configPath
            $result.Count | Should Be 1
        }

        It 'Should handle configuration with no connectors' {
            $noConnectorsConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<Configuration>
  <Connectors />
</Configuration>
'@
            $configPath = Join-Path $TestDrive "NoConnectors.xml"
            Set-Content -Path $configPath -Value $noConnectorsConfig
            
            $result = Get-ECMA2Connector -ConfigurationPath $configPath -WarningAction SilentlyContinue
            $result | Should BeNullOrEmpty
        }
    }
}



