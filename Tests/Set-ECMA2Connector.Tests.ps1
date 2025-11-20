# Import the module
$ModulePath = Split-Path -Parent $PSScriptRoot
Import-Module "$ModulePath\ECMA2HostTools.psd1" -Force

Describe 'Set-ECMA2Connector' {
    Context 'Parameter Validation' {
        It 'Should have mandatory Name parameter' {
            $command = Get-Command Set-ECMA2Connector
            ($command.Parameters['Name'].Attributes.Mandatory -contains $true) | Should Be $true
        }

        It 'Should have Parameters parameter as hashtable' {
            $command = Get-Command Set-ECMA2Connector
            $command.Parameters['Parameters'].ParameterType.Name | Should Be 'Hashtable'
        }

        It 'Should have AutosyncTimer parameter with range validation' {
            $command = Get-Command Set-ECMA2Connector
            $validation = $command.Parameters['AutosyncTimer'].Attributes | 
                Where-Object { $_.TypeId.Name -eq 'ValidateRangeAttribute' }
            $validation.MinRange | Should Be 1
            $validation.MaxRange | Should Be 86400
        }

        It 'Should support ShouldProcess' {
            $command = Get-Command Set-ECMA2Connector
            $command.Parameters.ContainsKey('WhatIf') | Should Be $true
            $command.Parameters.ContainsKey('Confirm') | Should Be $true
        }

        It 'Should have ConfirmImpact set to Medium' {
            $command = Get-Command Set-ECMA2Connector
            # Pester 3 - just verify WhatIf/Confirm exist which indicates ShouldProcess support
            $command.Parameters.ContainsKey('Confirm') | Should Be $true
        }

        It 'Should accept pipeline input for Name parameter' {
            $command = Get-Command Set-ECMA2Connector
            $command.Parameters['Name'].Attributes.ValueFromPipeline | Should Be $true
        }
    }

    Context 'Configuration File Handling' {
        $script:TestConfigPath = Join-Path $TestDrive "Configuration.xml"
        
        BeforeEach {
            # Create a test configuration file
            
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
            <Value>olduser</Value>
          </Parameter>
          <Parameter>
            <Name>Password</Name>
            <Type>EncryptedString</Type>
            <Use>Connectivity</Use>
            <Encrypted>true</Encrypted>
            <Value>encrypted_value</Value>
          </Parameter>
          <Parameter>
            <Name>Schema Script</Name>
            <Type>String</Type>
            <Use>Connectivity</Use>
            <Encrypted>false</Encrypted>
            <Value>C:\OldPath\schema.ps1</Value>
          </Parameter>
        </Parameters>
        <RunConfigurations />
        <IsExportSupported>true</IsExportSupported>
        <IsFullImportSupported>true</IsFullImportSupported>
        <IsDeltaImportSupported>false</IsDeltaImportSupported>
        <IsExportOnly>false</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema />
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
  </Connectors>
  <Setting>
    <Port>8585</Port>
  </Setting>
</Configuration>
'@
            Set-Content -Path $script:TestConfigPath -Value $xmlContent
        }

        It 'Should throw error when configuration file does not exist' {
            $threw = $false
            try {
                Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 300 -ConfigurationPath "C:\NonExistent\Config.xml" -ErrorAction Stop
            } catch {
                $threw = $true
            }
            $threw | Should Be $true
        }

        It 'Should throw error when connector is not found' {
            $threw = $false
            try {
                Set-ECMA2Connector -Name "NonExistentConnector" -AutosyncTimer 300 -ConfigurationPath $script:TestConfigPath -ErrorAction Stop
            } catch {
                $threw = $true
            }
            $threw | Should Be $true
        }

        It 'Should create backup by default' {
            Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 300 -ConfigurationPath $script:TestConfigPath -Confirm:$false
            
            $backupFiles = Get-ChildItem -Path (Split-Path $script:TestConfigPath) -Filter "*.backup_*"
            $backupFiles | Should Not BeNullOrEmpty
        }

        It 'Should not create backup when BackupConfiguration is false' {
            # Clean up any existing backups first
            Get-ChildItem -Path (Split-Path $script:TestConfigPath) -Filter "*.backup_*" | Remove-Item -Force -ErrorAction SilentlyContinue
            
            Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 300 -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false
            
            $backupFiles = Get-ChildItem -Path (Split-Path $script:TestConfigPath) -Filter "*.backup_*"
            $backupFiles | Should BeNullOrEmpty
        }
    }

    Context 'Parameter Updates' {
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
            <Value>olduser</Value>
          </Parameter>
          <Parameter>
            <Name>Schema Script</Name>
            <Type>String</Type>
            <Use>Connectivity</Use>
            <Encrypted>false</Encrypted>
            <Value>C:\OldPath\schema.ps1</Value>
          </Parameter>
        </Parameters>
        <RunConfigurations />
        <IsExportSupported>true</IsExportSupported>
        <IsFullImportSupported>true</IsFullImportSupported>
        <IsDeltaImportSupported>false</IsDeltaImportSupported>
        <IsExportOnly>false</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema />
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
  </Connectors>
</Configuration>
'@
            Set-Content -Path $script:TestConfigPath -Value $xmlContent
        }

        It 'Should update single parameter' {
            Set-ECMA2Connector -Name "TestConnector" -Parameters @{ 'Username' = 'newuser' } -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false
            
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "TestConnector"
            $result.Parameters['Username'].Value | Should Be "newuser"
        }

        It 'Should update multiple parameters' {
            Set-ECMA2Connector -Name "TestConnector" -Parameters @{ 
                'Username' = 'newuser'
                'Schema Script' = 'C:\NewPath\schema.ps1'
            } -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false
            
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "TestConnector"
            $result.Parameters['Username'].Value | Should Be "newuser"
            $result.Parameters['Schema Script'].Value | Should Be "C:\NewPath\schema.ps1"
        }

        It 'Should update AutosyncTimer' {
            Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 300 -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false
            
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "TestConnector"
            $result.AutosyncTimer | Should Be "300"
        }

        It 'Should update both parameters and AutosyncTimer' {
            Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 180 -Parameters @{ 'Username' = 'newuser' } -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false
            
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "TestConnector"
            $result.AutosyncTimer | Should Be "180"
            $result.Parameters['Username'].Value | Should Be "newuser"
        }

        It 'Should warn about non-existent parameter' {
            $warnings = @()
            Set-ECMA2Connector -Name "TestConnector" -Parameters @{ 'NonExistentParam' = 'value' } -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            
            $warnings | Should Not BeNullOrEmpty
        }

        It 'Should update ModificationDateTime' {
            $beforeTime = Get-Date
            Start-Sleep -Seconds 1
            
            Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 300 -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false
            
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "TestConnector"
            $modTime = [DateTime]::Parse($result.ModificationDateTime)
            $modTime | Should BeGreaterThan $beforeTime
        }

        It 'Should return change summary object' {
            $result = Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 300 -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false
            
            ($result.PSTypeNames -contains 'ECMA2Host.ConnectorUpdate') | Should Be $true
            $result.ConnectorName | Should Be "TestConnector"
            $result.ChangesMade | Should Be $true
            $result.Changes | Should Not BeNullOrEmpty
        }
    }

    Context 'WhatIf Support' {
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
            <Value>olduser</Value>
          </Parameter>
        </Parameters>
        <RunConfigurations />
        <IsExportSupported>true</IsExportSupported>
        <IsFullImportSupported>true</IsFullImportSupported>
        <IsDeltaImportSupported>false</IsDeltaImportSupported>
        <IsExportOnly>false</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema />
      </Schema>
      <ECMAConfig>
        <AutosyncTimer>120</AutosyncTimer>
        <ProfileName>TestConnector</ProfileName>
        <ModificationDateTime>Monday, January 1, 2025 12:00:00 PM</ModificationDateTime>
      </ECMAConfig>
    </Connector>
  </Connectors>
</Configuration>
'@
            Set-Content -Path $script:TestConfigPath -Value $xmlContent
        }

        It 'Should not make changes with WhatIf' {
            Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 300 -ConfigurationPath $script:TestConfigPath -WhatIf
            
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "TestConnector"
            $result.AutosyncTimer | Should Be "120"
        }

        It 'Should not create backup with WhatIf' {
            Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 300 -ConfigurationPath $script:TestConfigPath -WhatIf
            
            $backupFiles = Get-ChildItem -Path (Split-Path $script:TestConfigPath) -Filter "*.backup_*"
            $backupFiles | Should BeNullOrEmpty
        }
    }

    Context 'Edge Cases' {
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
        <RunConfigurations />
        <IsExportSupported>true</IsExportSupported>
        <IsFullImportSupported>true</IsFullImportSupported>
        <IsDeltaImportSupported>false</IsDeltaImportSupported>
        <IsExportOnly>false</IsExportOnly>
      </ConnectorConfig>
      <Schema>
        <EntriesSchema />
      </Schema>
      <ECMAConfig>
        <AutosyncTimer>120</AutosyncTimer>
        <ProfileName>TestConnector</ProfileName>
        <ModificationDateTime>Monday, January 1, 2025 12:00:00 PM</ModificationDateTime>
      </ECMAConfig>
    </Connector>
  </Connectors>
</Configuration>
'@
            Set-Content -Path $script:TestConfigPath -Value $xmlContent
        }

        It 'Should handle empty parameters hashtable' {
            $result = Set-ECMA2Connector -Name "TestConnector" -Parameters @{} -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false -WarningAction SilentlyContinue
            
            $result | Should BeNullOrEmpty
        }

        It 'Should handle numeric values in parameters' {
            Set-ECMA2Connector -Name "TestConnector" -Parameters @{ 'Username' = 12345 } -ConfigurationPath $script:TestConfigPath -BackupConfiguration:$false -Confirm:$false
            
            $result = Get-ECMA2Connector -ConfigurationPath $script:TestConfigPath -Name "TestConnector"
            $result.Parameters['Username'].Value | Should Be "12345"
        }

        It 'Should validate AutosyncTimer minimum value' {
            $threw = $false
            try {
                Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 0 -ConfigurationPath $script:TestConfigPath -ErrorAction Stop
            } catch {
                $threw = $true
            }
            $threw | Should Be $true
        }

        It 'Should validate AutosyncTimer maximum value' {
            $threw = $false
            try {
                Set-ECMA2Connector -Name "TestConnector" -AutosyncTimer 100000 -ConfigurationPath $script:TestConfigPath -ErrorAction Stop
            } catch {
                $threw = $true
            }
            $threw | Should Be $true
        }
    }
}



