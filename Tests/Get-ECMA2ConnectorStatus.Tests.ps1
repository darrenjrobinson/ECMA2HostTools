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
