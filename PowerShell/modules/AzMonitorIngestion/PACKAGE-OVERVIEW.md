# Azure Monitor Ingestion PowerShell Module - Package Overview

## 📦 Package Contents

This package contains a complete, production-ready PowerShell module for ingesting custom data into Azure Monitor Log Analytics.

### Files Included

```
AzMonitorIngestion/
├── AzMonitorIngestion.psm1      (31 KB)  - Main module file with all functions
├── AzMonitorIngestion.psd1      (4.3 KB) - Module manifest
├── README.md                    (18 KB)  - Comprehensive documentation
├── QUICKSTART.md                (9.7 KB) - Quick start guide
└── Examples.ps1                 (13 KB)  - Usage examples
```

---

## 🚀 What This Module Does

Provides a clean PowerShell interface to send custom data to Azure Monitor Log Analytics using:
- **Data Collection Endpoints (DCE)**
- **Data Collection Rules (DCR)**
- **Azure Monitor Logs Ingestion API**

### Key Features

✅ **Multiple Authentication Methods**
- System-assigned Managed Identity
- User-assigned Managed Identity
- Service Principal with Certificate (from store or file)
- Service Principal with Secret
- Interactive login (Azure PowerShell context)
- Azure CLI credentials

✅ **Production-Ready Features**
- Automatic batching for large datasets
- Retry logic with exponential backoff
- Comprehensive error handling
- Connection testing
- Permission verification

✅ **No JWT Complexity**
- Uses Az.Accounts module for token management
- No manual JWT handling required
- Azure RBAC-based authorization (not Graph API permissions)

---

## 📋 Functions Included

### 1. `Connect-AzMonitorIngestion`
Authenticate to Azure Monitor using various methods.

**Example:**
```powershell
Connect-AzMonitorIngestion -UseManagedIdentity
```

### 2. `Send-AzMonitorData`
Send custom log data to Azure Monitor.

**Example:**
```powershell
Send-AzMonitorData `
    -DceEndpoint "https://dce-prod.eastus-1.ingest.monitor.azure.com" `
    -DcrImmutableId "dcr-abc123..." `
    -StreamName "Custom-MyData_CL" `
    -Data $myData
```

### 3. `Test-AzMonitorIngestion`
Test DCE connectivity (DNS, TCP, HTTPS).

**Example:**
```powershell
Test-AzMonitorIngestion -DceEndpoint "https://dce-prod.eastus-1.ingest.monitor.azure.com"
```

### 4. `Test-AzMonitorPermissions`
Verify RBAC permissions on DCR.

**Example:**
```powershell
Test-AzMonitorPermissions -DcrResourceId $dcrId -PrincipalId $principalId
```

### 5. `Get-AzMonitorModuleInfo`
Display module version and authentication status.

**Example:**
```powershell
Get-AzMonitorModuleInfo
```

---

## 💡 Quick Installation

### Step 1: Install Prerequisites
```powershell
Install-Module -Name Az.Accounts -Scope CurrentUser
```

### Step 2: Install Module
```powershell
# Copy module to PowerShell modules directory
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\AzMonitorIngestion"
New-Item -Path $modulePath -ItemType Directory -Force

# Extract/copy all files from this package to $modulePath
```

### Step 3: Import and Verify
```powershell
Import-Module AzMonitorIngestion
Get-AzMonitorModuleInfo
```

---

## 🎯 Quick Start

### Minimal Example

```powershell
# 1. Import
Import-Module AzMonitorIngestion

# 2. Authenticate
Connect-AzAccount
Connect-AzMonitorIngestion -UseCurrentContext

# 3. Send Data
$data = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        Field1        = "value"
        Field2        = 123
    }
)

Send-AzMonitorData `
    -DceEndpoint "https://dce-prod.eastus-1.ingest.monitor.azure.com" `
    -DcrImmutableId "dcr-abc123..." `
    -StreamName "Custom-MyTable_CL" `
    -Data $data
```

---

## 📚 Documentation Structure

### README.md (Start Here)
- Complete feature overview
- All authentication methods with examples
- Advanced usage patterns
- Troubleshooting guide
- API details
- Best practices

### QUICKSTART.md (For Beginners)
- Step-by-step installation
- Prerequisites in Azure
- First data ingestion
- Common issues and solutions
- Quick reference card

### Examples.ps1 (Copy & Modify)
- 8 complete working examples:
  1. Interactive authentication
  2. Managed Identity
  3. Service Principal with Secret
  4. Large dataset batching
  5. Error handling
  6. Diagnostic tests
  7. Real-world compliance checks
  8. Scheduled task pattern

---

## 🔧 Azure Prerequisites

Before using this module, you need:

### Required Azure Resources
1. **Log Analytics Workspace** - Where data is stored
2. **Data Collection Endpoint (DCE)** - Ingestion endpoint
3. **Data Collection Rule (DCR)** - Schema and routing
4. **Custom Table** - In Log Analytics (with `_CL` suffix)

### Required Permission
- **"Monitoring Metrics Publisher"** role on the DCR
- Assigned to your identity (Service Principal, Managed Identity, or User)

**Important:** This is RBAC, not API permissions in App Registration!

---

## 🔐 Authentication Comparison

### What You DON'T Need (Unlike Graph API)
❌ No API permissions in App Registration  
❌ No admin consent  
❌ No "roles" claim in token  
❌ No Graph API scope  

### What You DO Need
✅ Azure RBAC role on DCR  
✅ Azure AD token for `https://monitor.azure.com`  
✅ Identity exists in Azure AD  

---

## 🏗️ Architecture

```
Your Script
    ↓
AzMonitorIngestion Module
    ↓ (uses Az.Accounts for auth)
Azure AD Token (audience: https://monitor.azure.com)
    ↓ (calls REST API)
Data Collection Endpoint (DCE)
    ↓ (validates via)
Data Collection Rule (DCR)
    ↓ (writes to)
Log Analytics Workspace
    ↓
Custom Table
```

**No Graph API involved!** This is Azure Resource Manager (ARM) + Azure Monitor API.

---

## 📊 Module Comparison

| Aspect | This Module | Official .NET SDK | Manual REST Calls |
|--------|-------------|-------------------|-------------------|
| **PowerShell Native** | ✅ Yes | ❌ Complex | ⚠️ Verbose |
| **Auth Methods** | ✅ 6 methods | ⚠️ Limited | ⚠️ Manual |
| **Batching** | ✅ Automatic | ✅ Yes | ❌ Manual |
| **Retry Logic** | ✅ Built-in | ❌ Manual | ❌ Manual |
| **Error Handling** | ✅ Detailed | ⚠️ Basic | ❌ Manual |
| **Diagnostics** | ✅ Built-in | ❌ None | ❌ None |
| **Production Ready** | ✅ Yes | ⚠️ With work | ❌ Requires work |

---

## 🎬 Real-World Use Cases

### 1. Compliance Monitoring
Collect compliance check results from servers and send to Log Analytics for dashboards.

### 2. Application Telemetry
Send custom application metrics that aren't available through Application Insights.

### 3. Security Event Aggregation
Collect security events from multiple sources into a central Log Analytics workspace.

### 4. Cost Analysis
Aggregate cost data from various sources for unified reporting.

### 5. Scheduled Health Checks
Azure Automation Runbooks that run hourly/daily health checks and log results.

---

## 🔍 Troubleshooting Quick Reference

| Error Code | Cause | Solution |
|------------|-------|----------|
| 401 | Token expired | Re-run `Connect-AzMonitorIngestion` |
| 403 | Missing RBAC role | Assign "Monitoring Metrics Publisher" on DCR |
| 404 | Wrong DCR/Stream | Verify IDs with `Get-AzDataCollectionRule` |
| 413 | Payload too large | Reduce `-BatchSize` parameter |
| 429 | Rate limited | Add `-ThrottleOnFailure` switch |

---

## 📦 What Makes This Different

### From Graph API
- Uses **Azure RBAC** instead of consent-based permissions
- Token audience is `https://monitor.azure.com` not `https://graph.microsoft.com`
- No API permissions in App Registration required
- No admin consent required

### From Manual REST Calls
- Clean PowerShell syntax
- Automatic authentication handling
- Built-in batching and retry
- Comprehensive error messages
- Diagnostic tools included

### From .NET SDK
- Pure PowerShell (no .NET assembly management)
- More authentication options
- Better error handling for PowerShell users
- Includes diagnostic functions

---

## 🛠️ Customization

The module is designed to be:
- **Extensible** - Add your own helper functions
- **Modifiable** - Source code is clean and well-commented
- **Reusable** - Works with any DCR/DCE/Table combination

### Example: Add Custom Wrapper

```powershell
function Send-ComplianceData {
    param([array]$Checks)
    
    # Transform your data format
    $data = $Checks | ForEach-Object {
        [PSCustomObject]@{
            TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
            CheckName     = $_.Name
            Status        = $_.Result
            Score         = $_.Score
        }
    }
    
    # Use module function
    Send-AzMonitorData `
        -DceEndpoint $env:DCE_ENDPOINT `
        -DcrImmutableId $env:DCR_ID `
        -StreamName "Custom-Compliance_CL" `
        -Data $data
}
```

---

## 📈 Version History

### 1.0.0 (Current)
- Initial release
- 6 authentication methods
- Automatic batching
- Retry logic with exponential backoff
- Diagnostic tools
- Comprehensive documentation

---

## 🤝 Support

### Documentation
- `README.md` - Complete reference
- `QUICKSTART.md` - Beginner guide
- `Examples.ps1` - Working examples
- Built-in help: `Get-Help <function-name> -Full`

### Azure Resources
- [Azure Monitor Documentation](https://docs.microsoft.com/azure/azure-monitor/)
- [Logs Ingestion API](https://docs.microsoft.com/azure/azure-monitor/logs/logs-ingestion-api-overview)
- [Azure Status](https://status.azure.com)

---

## ✅ Getting Started Checklist

Before first use:

- [ ] Install Az.Accounts module
- [ ] Extract/copy module files to PowerShell modules directory
- [ ] Import module: `Import-Module AzMonitorIngestion`
- [ ] Verify installation: `Get-AzMonitorModuleInfo`
- [ ] Have DCE endpoint URL
- [ ] Have DCR Immutable ID
- [ ] Have Stream Name (Custom-TableName_CL)
- [ ] Assigned "Monitoring Metrics Publisher" role on DCR
- [ ] Test connectivity: `Test-AzMonitorIngestion -DceEndpoint $dce`
- [ ] Send first test data
- [ ] Query data in Log Analytics (wait 2-5 minutes)

---

## 📧 Module Information

- **Version:** 1.0.0
- **Author:** IT Operations Team
- **PowerShell:** 5.1 or later
- **Dependencies:** Az.Accounts (2.0.0+)
- **License:** Internal use

---

## 🚀 Next Steps

1. **Read QUICKSTART.md** for installation and first steps
2. **Review Examples.ps1** for common patterns
3. **Reference README.md** for detailed documentation
4. **Test in dev** before production deployment
5. **Set up monitoring** for ingestion success/failure

---

**This module provides everything you need for production-ready Azure Monitor data ingestion from PowerShell!** 🎯

For questions or issues, refer to the troubleshooting sections in README.md and QUICKSTART.md.
