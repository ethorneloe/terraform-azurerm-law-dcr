# Quick Start Guide - Azure Monitor Ingestion Module

## Installation

### Step 1: Install Required Module

```powershell
# Install Az.Accounts if not already installed
Install-Module -Name Az.Accounts -Scope CurrentUser -Force
```

### Step 2: Install AzMonitorIngestion Module

#### Option A: Copy to PowerShell Modules Directory (Recommended)

```powershell
# Create module directory
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\AzMonitorIngestion"
New-Item -Path $modulePath -ItemType Directory -Force

# Copy module files to the directory
# (Copy AzMonitorIngestion.psm1 and AzMonitorIngestion.psd1 to $modulePath)
```

#### Option B: Import from Current Directory

```powershell
# Navigate to module directory
cd C:\Path\To\AzMonitorIngestion

# Import module
Import-Module .\AzMonitorIngestion.psd1 -Force
```

### Step 3: Verify Installation

```powershell
# Import module
Import-Module AzMonitorIngestion

# Check module info
Get-AzMonitorModuleInfo

# List available commands
Get-Command -Module AzMonitorIngestion
```

Expected output:
```
=== Azure Monitor Ingestion Module ===
Version: 1.0.0

Authentication Status:
  ✗ Not authenticated
  Run: Connect-AzMonitorIngestion

Available Commands:
  - Connect-AzMonitorIngestion
  - Get-AzMonitorModuleInfo
  - Send-AzMonitorData
  - Test-AzMonitorIngestion
  - Test-AzMonitorPermissions
```

---

## Prerequisites in Azure

Before using the module, you need these Azure resources:

### 1. Log Analytics Workspace
```powershell
# Get existing workspace
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "rg-monitoring" -Name "law-prod-001"
```

### 2. Data Collection Endpoint (DCE)
```powershell
# Get DCE endpoint
$dce = Get-AzDataCollectionEndpoint -ResourceGroupName "rg-monitoring" -Name "dce-prod-shared"
$dceEndpoint = $dce.LogsIngestionEndpoint
Write-Host "DCE Endpoint: $dceEndpoint"
```

### 3. Custom Table and Data Collection Rule (DCR)

See the Terraform module examples for creating these, or create via Portal:
- Navigate to Log Analytics Workspace
- Create custom table with `_CL` suffix
- Create Data Collection Rule linking DCE to the table

### 4. RBAC Assignment

**Critical:** Assign "Monitoring Metrics Publisher" role on the DCR

```powershell
# Get your identity
$context = Get-AzContext
$principalId = (Get-AzADUser -UserPrincipalName $context.Account.Id).Id

# Assign role
$dcr = Get-AzDataCollectionRule -ResourceGroupName "rg-monitoring" -Name "dcr-MyData_CL"
New-AzRoleAssignment `
    -RoleDefinitionName "Monitoring Metrics Publisher" `
    -ObjectId $principalId `
    -Scope $dcr.Id

Write-Host "✓ Role assigned. Wait 5-10 minutes for propagation."
```

---

## Quick Start: Send Your First Data

### 1. Authenticate

```powershell
# Import module
Import-Module AzMonitorIngestion

# Authenticate (interactive)
Connect-AzAccount
Connect-AzMonitorIngestion -UseCurrentContext
```

### 2. Configure Your Endpoints

```powershell
# Get these from Azure Portal or PowerShell
$config = @{
    DceEndpoint    = "https://dce-prod-shared-abc.eastus-1.ingest.monitor.azure.com"
    DcrImmutableId = "dcr-abc123def456..."  # From DCR properties
    StreamName     = "Custom-MyData_CL"      # Must match DCR stream declaration
}

# Save for reuse
$config | Export-Clixml -Path "$env:USERPROFILE\AzMonitor-Config.xml"
```

### 3. Test Connectivity

```powershell
# Test DCE connectivity
Test-AzMonitorIngestion -DceEndpoint $config.DceEndpoint
```

Expected output:
```
Testing connection to: https://dce-prod-shared-abc.eastus-1.ingest.monitor.azure.com
  [1/3] Testing DNS resolution... ✓ Public IP: 20.x.x.x
  [2/3] Testing TCP connectivity (port 443)... ✓ Connected
  [3/3] Testing HTTPS endpoint... ✓ Reachable (404 expected)

✓ All connectivity tests passed
```

### 4. Send Test Data

```powershell
# Create sample data
$testData = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        ServerName    = $env:COMPUTERNAME
        Status        = "Test"
        Value         = 123
    }
)

# Send to Log Analytics
Send-AzMonitorData `
    -DceEndpoint $config.DceEndpoint `
    -DcrImmutableId $config.DcrImmutableId `
    -StreamName $config.StreamName `
    -Data $testData `
    -Verbose
```

Expected output:
```
VERBOSE: Azure Monitor Data Ingestion starting...
VERBOSE: DCE: https://dce-prod-shared-abc.eastus-1.ingest.monitor.azure.com
VERBOSE: DCR: dcr-abc123def456...
VERBOSE: Stream: Custom-MyData_CL
VERBOSE: Records: 1
VERBOSE: Acquiring access token for Azure Monitor...
VERBOSE: ✓ Access token acquired
VERBOSE: Endpoint: https://dce-prod-shared-abc.eastus-1.ingest.monitor.azure.com/dataCollectionRules/...
VERBOSE: Splitting into 1 batch(es) of max 1000 records
VERBOSE: Processing batch 1/1 (1 records)
VERBOSE: Attempt 1 of 3...
VERBOSE: ✓ Batch 1 sent successfully
VERBOSE: Ingestion complete
VERBOSE: Total records: 1
VERBOSE: Successful: 1
VERBOSE: Failed: 0
✓ Successfully sent 1 of 1 records
```

### 5. Query Your Data

Wait 2-5 minutes for data to appear, then query:

```powershell
# Using PowerShell
$query = @"
MyData_CL
| where TimeGenerated > ago(1h)
| order by TimeGenerated desc
| take 10
"@

Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $query
```

Or in Azure Portal:
1. Navigate to Log Analytics Workspace
2. Click "Logs"
3. Query your table:
   ```kql
   MyData_CL
   | where TimeGenerated > ago(1h)
   | take 10
   ```

---

## Common First-Time Issues

### Issue 1: "Not authenticated" Error

```
Error: Not authenticated. Run Connect-AzMonitorIngestion first.
```

**Solution:**
```powershell
Connect-AzAccount
Connect-AzMonitorIngestion -UseCurrentContext
```

### Issue 2: 403 Forbidden Error

```
Error: HTTP 403 - Authorization failed
```

**Cause:** Missing RBAC role

**Solution:**
```powershell
# Assign role (requires Owner or User Access Administrator on DCR)
$dcr = Get-AzDataCollectionRule -ResourceGroupName "rg-monitoring" -Name "dcr-MyData_CL"
$principalId = (Get-AzContext).Account.ExtendedProperties.HomeAccountId.Split('.')[0]

New-AzRoleAssignment `
    -RoleDefinitionName "Monitoring Metrics Publisher" `
    -ObjectId $principalId `
    -Scope $dcr.Id

# Wait 5-10 minutes, then retry
```

### Issue 3: 404 Not Found Error

```
Error: HTTP 404 - Resource not found
```

**Cause:** Incorrect DCR ID or stream name

**Solution:**
```powershell
# Get correct IDs
$dcr = Get-AzDataCollectionRule -ResourceGroupName "rg-monitoring" -Name "dcr-MyData_CL"
Write-Host "DCR Immutable ID: $($dcr.ImmutableId)"
Write-Host "Stream Name: Custom-MyData_CL"  # Must match DCR configuration
```

### Issue 4: Data Not Appearing in Log Analytics

**Possible causes:**
1. Wait 2-5 minutes (ingestion latency)
2. Check for ingestion errors in DCR metrics
3. Verify schema matches DCR stream declaration
4. Check table name (must query with `_CL` suffix)

**Debug:**
```powershell
# Check DCR metrics in Azure Portal
# Monitor → Data Collection Rules → {your DCR} → Metrics
# Metric: "Logs Rows Received" or "Logs Ingestion Failed"
```

---

## Next Steps

### For Production Use

1. **Use Managed Identity** (if on Azure VM/Function)
   ```powershell
   Connect-AzMonitorIngestion -UseManagedIdentity
   ```

2. **Store Configuration Securely**
   ```powershell
   # Use Azure Key Vault
   $dce = (Get-AzKeyVaultSecret -VaultName "kv-prod" -Name "DCE-Endpoint").SecretValueText
   ```

3. **Implement Error Handling**
   ```powershell
   try {
       $result = Send-AzMonitorData -DceEndpoint $dce -DcrImmutableId $dcr -StreamName $stream -Data $data
       if (-not $result.Success) {
           # Alert or log failure
       }
   }
   catch {
       # Handle critical errors
   }
   ```

4. **Schedule Regular Ingestion**
   - Azure Automation Runbook (recommended for Azure)
   - Windows Task Scheduler
   - Cron job (Linux)

### Learn More

- Review `Examples.ps1` for common patterns
- Read `README.md` for detailed documentation
- Check `Get-Help` for each function:
  ```powershell
  Get-Help Connect-AzMonitorIngestion -Full
  Get-Help Send-AzMonitorData -Full
  Get-Help Test-AzMonitorIngestion -Full
  ```

---

## Support Checklist

If you encounter issues, gather this information:

```powershell
# Module version
Get-AzMonitorModuleInfo

# Authentication status
Get-AzContext

# DCE connectivity
Test-AzMonitorIngestion -DceEndpoint $dceEndpoint

# RBAC permissions (if you have the IDs)
Test-AzMonitorPermissions -DcrResourceId $dcrId -PrincipalId $principalId

# Azure Monitor service health
# Visit: https://status.azure.com
```

---

## Quick Reference Card

### Essential Commands

```powershell
# Setup
Import-Module AzMonitorIngestion
Connect-AzMonitorIngestion -UseCurrentContext

# Send data
Send-AzMonitorData -DceEndpoint $dce -DcrImmutableId $dcr -StreamName $stream -Data $data

# Test
Test-AzMonitorIngestion -DceEndpoint $dce

# Help
Get-Help Send-AzMonitorData -Full
```

### Required Azure Resources

| Resource | Example Value |
|----------|---------------|
| DCE Endpoint | `https://dce-name.region.ingest.monitor.azure.com` |
| DCR Immutable ID | `dcr-abc123def456...` |
| Stream Name | `Custom-TableName_CL` |
| RBAC Role | `Monitoring Metrics Publisher` (on DCR) |

### Data Format

```powershell
$data = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")  # ISO 8601 format
        Field1        = "value"
        Field2        = 123
    }
)
```

---

## Getting Help

For detailed help on any command:

```powershell
Get-Help <command-name> -Full
Get-Help <command-name> -Examples
Get-Help <command-name> -Parameter <parameter-name>
```

Examples:
```powershell
Get-Help Connect-AzMonitorIngestion -Full
Get-Help Send-AzMonitorData -Examples
Get-Help Send-AzMonitorData -Parameter BatchSize
```

---

**You're now ready to start ingesting custom data to Azure Monitor!** 🎉
