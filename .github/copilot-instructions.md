<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

## PowerShell Module for ECMA2Host Orchestration

This workspace contains a PowerShell module for orchestrating ECMA2Host and its connectors in Microsoft Identity Manager (MIM) / FIM Sync Engine environments.

### Module Structure
- Use approved PowerShell verbs for all function names
- Follow PowerShell module best practices
- Include proper error handling and logging
- Support pipeline input where appropriate
- Use Comment-Based Help for all public functions

### ECMA2Host Context
- ECMA2Host is the Extensible Connectivity Management Agent 2.0 host service
- Connectors implement ECMA2 interface for synchronization with external systems
- Module should support connector lifecycle management (start, stop, configure, monitor)
- Handle connector space operations and run profiles

### Code Style
- Use PascalCase for function names
- Use proper parameter validation attributes
- Include Verbose and Debug output where appropriate
- Follow PSScriptAnalyzer rules
