@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzMonitorIngestion.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-4a5b-8c7d-9e8f7a6b5c4d'
    
    # Author of this module
    Author = 'IT Operations Team'
    
    # Company or vendor of this module
    CompanyName = 'IT Operations'
    
    # Copyright statement for this module
    Copyright = '(c) 2024 IT Operations. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'PowerShell module for sending custom log data to Azure Monitor via Data Collection Endpoints. Supports multiple authentication methods including Managed Identity, Service Principal with Certificate or Secret, and interactive login. Provides automatic batching, retry logic, and comprehensive error handling for production-ready data ingestion.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{
            ModuleName = 'Az.Accounts'
            ModuleVersion = '2.0.0'
        }
    )
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry
    FunctionsToExport = @(
        'Connect-AzMonitorIngestion',
        'Send-AzMonitorData',
        'Test-AzMonitorIngestion',
        'Test-AzMonitorPermissions',
        'Get-AzMonitorModuleInfo'
    )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @(
                'Azure',
                'AzureMonitor',
                'LogAnalytics',
                'Monitoring',
                'Logging',
                'DataCollectionRule',
                'DCR',
                'DCE',
                'Ingestion',
                'CustomLogs',
                'ManagedIdentity',
                'ServicePrincipal'
            )
            
            # A URL to the license for this module.
            LicenseUri = ''
            
            # A URL to the main website for this project.
            ProjectUri = ''
            
            # A URL to an icon representing this module.
            IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 1.0.0 (Initial Release)

### Features
- Multiple authentication methods:
  - System-assigned Managed Identity
  - User-assigned Managed Identity
  - Service Principal with Certificate (from store or file)
  - Service Principal with Secret
  - Interactive login (current Azure context)
  - Azure CLI credentials

- Data ingestion capabilities:
  - Automatic batching for large datasets
  - Configurable batch sizes (1-10,000 records)
  - Retry logic with exponential backoff
  - Comprehensive error handling and reporting

- Diagnostic tools:
  - Connection testing (DNS, TCP, HTTPS)
  - Permission verification (RBAC checks)
  - Module status display

### Requirements
- PowerShell 5.1 or later
- Az.Accounts module (2.0.0 or later)
- Azure Monitor Logs Ingestion API (api-version 2023-01-01)

### Notes
- No API permissions required in App Registration (uses Azure RBAC)
- Requires 'Monitoring Metrics Publisher' role on Data Collection Rule
- Works with both public and private Data Collection Endpoints
'@
        }
    }
    
    # HelpInfo URI of this module
    HelpInfoURI = ''
    
    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    DefaultCommandPrefix = ''
}
