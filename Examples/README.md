# Examples

This directory contains example scripts demonstrating how to use the ECMA2HostTools module.

## Available Examples

### Service Management
`ServiceManagement.ps1` - Examples of starting, stopping, and monitoring the ECMA2Host service
- Start and stop the ECMA2Host service
- Check service status
- Monitor service health

### Connector Operations
`ConnectorOperations.ps1` - Examples of working with connectors
- Get connector information
- Update connector parameters
- Query connector status
- Work with connector objects

### Configuration Management
`ConfigurationManagement.ps1` - Examples of managing connector configurations
- Export connector configurations to JSON
- Import connector configurations
- Backup and restore complete ECMA2Host configuration
- Migration scenarios

### Recently Modified Objects
`Get-RecentlyModifiedObjects.ps1` - Retrieve objects modified within a time range
- Filter objects by hours, days, or minutes
- Filter by specific datetime
- Display progress during retrieval
- Useful for monitoring recent changes

### Send User Create Request
`Send-UserCreate.ps1` and `Send-UserCreateRequest.ps1` - Examples of creating users via SCIM API
- Create new users in a connector
- Send SCIM POST requests
- Handle API responses

### Validate Connector Caches
`Validate-ConnectorCaches.ps1` - Validate and monitor connector cache status
- Check object counts across connectors
- Compare cache sizes
- Verify connector health

### Export All Connectors with Documentation
`Export-AllConnectorsWithDocs.ps1` - Generate comprehensive connector documentation
- Export all connector configurations
- Generate markdown documentation for each connector
- Create a complete backup with documentation

## Usage

Each example script can be run independently:
```powershell
# Basic examples
.\Examples\ServiceManagement.ps1
.\Examples\ConnectorOperations.ps1

# Configuration management
.\Examples\ConfigurationManagement.ps1

# Query recently modified objects
.\Examples\Get-RecentlyModifiedObjects.ps1 -ConnectorName "LDAPConnector" -Hours 24

# Validate connector caches
.\Examples\Validate-ConnectorCaches.ps1

# Export all connectors with documentation
.\Examples\Export-AllConnectorsWithDocs.ps1
```

Make sure the ECMA2HostTools module is imported before running examples:
```powershell
Import-Module ECMA2HostTools
```

## Prerequisites

- ECMA2HostTools module installed and imported
- ECMA2Host service installed and configured
- Appropriate permissions to access ECMA2Host configuration
- Administrator privileges required for service management operations
