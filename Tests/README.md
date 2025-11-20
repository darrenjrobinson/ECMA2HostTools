# Tests Directory

This directory contains Pester tests for the ECMA2HostTools module.

## Running Tests

To run all tests:
```powershell
Invoke-Pester
```

To run tests for a specific function:
```powershell
Invoke-Pester -Path .\Tests\Start-ECMA2Host.Tests.ps1
```

## Test Structure

Each public function should have a corresponding test file following the naming convention:
`FunctionName.Tests.ps1`

Tests should cover:
- Parameter validation
- Expected behavior
- Error handling
- Edge cases
- Pipeline input
