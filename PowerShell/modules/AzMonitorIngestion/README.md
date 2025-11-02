# Azure Monitor Ingestion Module

PowerShell module for sending custom log data to Azure Monitor via Data Collection Endpoints (DCE) using the Logs Ingestion API.

## Overview

This module provides a clean, PowerShell-native interface for ingesting custom data into Azure Monitor Log Analytics workspaces. It supports multiple authentication methods, automatic batching, retry logic, and comprehensive error handling for production-ready deployments.

## Features

### Multiple Authentication Methods
- ✅ **System-assigned Managed Identity** - For Azure VMs, Function Apps, etc.
- ✅ **User-assigned Managed Identity** - For resources with UAI enabled
- ✅ **Service Principal with Certificate** - From Windows certificate store or file
- ✅ **Service Principal with Secret** - Client secret authentication
- ✅ **Interactive Login** - Use current Azure PowerShell context
- ✅ **Azure CLI** - Use Azure CLI credentials

### Production Features
- ✅ **Automatic batching** - Handles large datasets efficiently
- ✅ **Retry logic** - Automatic retry with exponential backoff
- ✅ **Error handling** - Detailed error messages with remediation steps
- ✅ **Connection testing** - Diagnostic tools for troubleshooting
- ✅ **Permission verification** - Check RBAC assignments
- ✅ **Private endpoint support** - Works with Azure Monitor Private Link Scope

## Requirements

- **PowerShell**: 5.1 or later (Windows PowerShell or PowerShell Core)
- **Az.Accounts Module**: 2.0.0 or later
- **Azure Resources**:
  - Data Collection Endpoint (DCE)
  - Data Collection Rule (DCR)
  - Log Analytics Workspace with custom table
  - RBAC: "Monitoring Metrics Publisher" role on DCR

## Installation

### Option 1: Manual Installation

```powershell
# Copy module to PowerShell modules directory
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\AzMonitorIngestion"
New-Item -Path $modulePath -ItemType Directory -Force

# Copy module files
Copy-Item AzMonitorIngestion.psm1 $modulePath\
Copy-Item AzMonitorIngestion.psd1 $modulePath\
```

### Option 2: Import from Local Directory

```powershell
# Import directly from current directory
Import-Module .\AzMonitorIngestion.psm1 -Force
```

### Verify Installation

```powershell
Import-Module AzMonitorIngestion
Get-AzMonitorModuleInfo
```

## Quick Start

### Basic Usage

```powershell
# 1. Import module
Import-Module AzMonitorIngestion

# 2. Authenticate (using current Azure context)
Connect-AzAccount
Connect-AzMonitorIngestion -UseCurrentContext

# 3. Prepare data
$data = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        ServerName    = "WEB-01"
        Status        = "PASS"
        Score         = 95
    }
)

# 4. Send data
Send-AzMonitorData `
    -DceEndpoint "https://dce-prod-abc.eastus-1.ingest.monitor.azure.com" `
    -DcrImmutableId "dcr-abc123def456..." `
    -StreamName "Custom-ComplianceChecks_CL" `
    -Data $data `
    -Verbose
```

## Authentication Examples

### Managed Identity (System-Assigned)

```powershell
# For Azure VMs, Function Apps, Container Instances, etc.
Connect-AzMonitorIngestion -UseManagedIdentity

Send-AzMonitorData `
    -DceEndpoint $env:DCE_ENDPOINT `
    -DcrImmutableId $env:DCR_ID `
    -StreamName $env:STREAM_NAME `
    -Data $myData
```

### Managed Identity (User-Assigned)

```powershell
Connect-AzMonitorIngestion -UserAssignedIdentityClientId "12345678-1234-1234-1234-123456789012"

Send-AzMonitorData `
    -DceEndpoint $dce `
    -DcrImmutableId $dcr `
    -StreamName $stream `
    -Data $myData
```

### Service Principal with Certificate (Certificate Store)

```powershell
Connect-AzMonitorIngestion `
    -ServicePrincipalCertificate `
    -TenantId "your-tenant-id" `
    -ApplicationId "your-app-id" `
    -CertificateThumbprint "ABC123DEF456..."

Send-AzMonitorData `
    -DceEndpoint $dce `
    -DcrImmutableId $dcr `
    -StreamName $stream `
    -Data $myData
```

### Service Principal with Certificate (File)

```powershell
$certPassword = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force

Connect-AzMonitorIngestion `
    -TenantId "your-tenant-id" `
    -ApplicationId "your-app-id" `
    -CertificatePath "C:\certs\monitoring-app.pfx" `
    -CertificatePassword $certPassword

Send-AzMonitorData `
    -DceEndpoint $dce `
    -DcrImmutableId $dcr `
    -StreamName $stream `
    -Data $myData
```

### Service Principal with Secret

```powershell
$secret = ConvertTo-SecureString "your-client-secret" -AsPlainText -Force

Connect-AzMonitorIngestion `
    -TenantId "your-tenant-id" `
    -ApplicationId "your-app-id" `
    -ServicePrincipalSecret $secret

Send-AzMonitorData `
    -DceEndpoint $dce `
    -DcrImmutableId $dcr `
    -StreamName $stream `
    -Data $myData
```

### Azure CLI Credentials

```powershell
# Login with Azure CLI
az login

# Use CLI credentials
Connect-AzMonitorIngestion -UseAzureCli

Send-AzMonitorData `
    -DceEndpoint $dce `
    -DcrImmutableId $dcr `
    -StreamName $stream `
    -Data $myData
```

## Advanced Usage

### Large Dataset with Batching

```powershell
# Generate large dataset
$largeDataset = 1..5000 | ForEach-Object {
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        RecordId      = $_
        ServerName    = "WEB-$($_ % 10)"
        Status        = @("PASS", "WARN", "FAIL")[Get-Random -Maximum 3]
        Score         = Get-Random -Minimum 50 -Maximum 100
    }
}

# Send with custom batch size and retry settings
$result = Send-AzMonitorData `
    -DceEndpoint $dce `
    -DcrImmutableId $dcr `
    -StreamName $stream `
    -Data $largeDataset `
    -BatchSize 500 `
    -RetryAttempts 5 `
    -ThrottleOnFailure `
    -Verbose

# Check results
if ($result.Success) {
    Write-Host "All data sent successfully!"
} else {
    Write-Warning "Some batches failed. Check logs."
}
```

### Error Handling

```powershell
try {
    $result = Send-AzMonitorData `
        -DceEndpoint $dce `
        -DcrImmutableId $dcr `
        -StreamName $stream `
        -Data $data `
        -ErrorAction Stop
    
    Write-Host "✓ Sent $($result.SuccessfulSends) records" -ForegroundColor Green
}
catch {
    Write-Error "Ingestion failed: $_"
    
    # Common error codes
    switch ($_.Exception.Response.StatusCode.value__) {
        401 { Write-Host "Re-authenticate with Connect-AzMonitorIngestion" }
        403 { Write-Host "Check RBAC: Monitoring Metrics Publisher role required on DCR" }
        404 { Write-Host "Verify DCR ID and stream name" }
        413 { Write-Host "Reduce batch size" }
        429 { Write-Host "Rate limited - reduce frequency" }
    }
}
```

### Scheduled Ingestion (Azure Automation Runbook)

```powershell
<#
.SYNOPSIS
    Azure Automation Runbook - Hourly Compliance Check
#>

Import-Module AzMonitorIngestion

# Get configuration from Automation Variables
$dce = Get-AutomationVariable -Name 'DCE_Endpoint'
$dcr = Get-AutomationVariable -Name 'DCR_ImmutableId'
$stream = Get-AutomationVariable -Name 'Stream_Name'

try {
    # Authenticate using system-assigned managed identity
    Connect-AzMonitorIngestion -UseManagedIdentity
    
    # Test connection
    if (-not (Test-AzMonitorIngestion -DceEndpoint $dce)) {
        throw "DCE connectivity test failed"
    }
    
    # Collect compliance data
    $complianceData = @()
    
    # Example: Check disk space
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
        $freePercent = ($_.Free / ($_.Used + $_.Free)) * 100
        $complianceData += [PSCustomObject]@{
            TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
            CheckName     = "DiskSpace_$($_.Name)"
            Status        = if ($freePercent -gt 20) { "PASS" } else { "WARN" }
            Score         = [int]$freePercent
            Details       = "Free: $([math]::Round($_.Free/1GB, 2)) GB"
        }
    }
    
    # Send to Log Analytics
    $result = Send-AzMonitorData `
        -DceEndpoint $dce `
        -DcrImmutableId $dcr `
        -StreamName $stream `
        -Data $complianceData `
        -Verbose
    
    Write-Output "✓ Compliance check complete. Sent $($result.SuccessfulSends) records."
}
catch {
    Write-Error "Runbook failed: $_"
    throw
}
```

## Diagnostic Tools

### Test DCE Connectivity

```powershell
# Test DNS, TCP, and HTTPS connectivity
Test-AzMonitorIngestion -DceEndpoint "https://dce-prod.eastus-1.ingest.monitor.azure.com"
```

### Verify RBAC Permissions

```powershell
# Check if identity has required role on DCR
$dcrId = "/subscriptions/{sub}/resourceGroups/rg-monitoring/providers/Microsoft.Insights/dataCollectionRules/dcr-MyData_CL"
$principalId = "12345678-1234-1234-1234-123456789012"  # Object ID of your identity

Test-AzMonitorPermissions -DcrResourceId $dcrId -PrincipalId $principalId
```

### Module Status

```powershell
# Display authentication status and available commands
Get-AzMonitorModuleInfo
```

## Configuration

### Required Azure RBAC Role

Your identity (Service Principal, Managed Identity, or User) must have the following role on the Data Collection Rule:

**Role:** `Monitoring Metrics Publisher`

#### Assign via Azure Portal

1. Navigate to your **Data Collection Rule**
2. Click **Access Control (IAM)**
3. Click **Add** → **Add role assignment**
4. Select **Monitoring Metrics Publisher**
5. Assign to your identity
6. Save

#### Assign via PowerShell

```powershell
$dcrId = "/subscriptions/{sub}/resourceGroups/rg-monitoring/providers/Microsoft.Insights/dataCollectionRules/dcr-MyData_CL"
$principalId = "12345678-1234-1234-1234-123456789012"

New-AzRoleAssignment `
    -RoleDefinitionName "Monitoring Metrics Publisher" `
    -ObjectId $principalId `
    -Scope $dcrId
```

#### Assign via Terraform

```hcl
resource "azurerm_role_assignment" "dcr_publisher" {
  scope                = azurerm_monitor_data_collection_rule.example.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = data.azurerm_user_assigned_identity.example.principal_id
}
```

### Finding Required IDs

#### DCR Immutable ID

```powershell
# Option 1: PowerShell
$dcr = Get-AzDataCollectionRule -ResourceGroupName "rg-monitoring" -Name "dcr-MyData_CL"
Write-Host "Immutable ID: $($dcr.ImmutableId)"

# Option 2: Azure CLI
az monitor data-collection rule show -g rg-monitoring -n dcr-MyData_CL --query immutableId -o tsv
```

#### DCE Logs Ingestion Endpoint

```powershell
# Option 1: PowerShell
$dce = Get-AzDataCollectionEndpoint -ResourceGroupName "rg-monitoring" -Name "dce-prod"
Write-Host "Endpoint: $($dce.LogsIngestionEndpoint)"

# Option 2: Azure Portal
# Navigate to DCE → Overview → Copy "Logs Ingestion" URL
```

#### Principal Object ID

```powershell
# For Service Principal
$sp = Get-AzADServicePrincipal -DisplayName "MyApp"
Write-Host "Object ID: $($sp.Id)"

# For Managed Identity
$vm = Get-AzVM -ResourceGroupName "rg-vms" -Name "vm-myapp"
Write-Host "Object ID: $($vm.Identity.PrincipalId)"
```

## Troubleshooting

### Common Errors

#### Error: 401 Unauthorized

**Cause:** Token expired or invalid authentication

**Solution:**
```powershell
# Re-authenticate
Connect-AzMonitorIngestion -UseManagedIdentity
```

#### Error: 403 Forbidden

**Cause:** Missing "Monitoring Metrics Publisher" role on DCR

**Solution:**
```powershell
# Assign role
New-AzRoleAssignment `
    -RoleDefinitionName "Monitoring Metrics Publisher" `
    -ObjectId $principalId `
    -Scope $dcrId

# Wait 5-10 minutes for role propagation
```

#### Error: 404 Not Found

**Cause:** Incorrect DCR ID or stream name

**Solution:**
```powershell
# Verify DCR exists and get correct IDs
$dcr = Get-AzDataCollectionRule -ResourceGroupName "rg-monitoring" -Name "dcr-MyData_CL"
Write-Host "Immutable ID: $($dcr.ImmutableId)"
Write-Host "Stream Name: Custom-MyData_CL"  # Must match DCR stream declaration
```

#### Error: 413 Payload Too Large

**Cause:** Batch size too large

**Solution:**
```powershell
# Reduce batch size
Send-AzMonitorData `
    -DceEndpoint $dce `
    -DcrImmutableId $dcr `
    -StreamName $stream `
    -Data $data `
    -BatchSize 500  # Reduce from default 1000
```

#### Error: 429 Rate Limited

**Cause:** Too many requests

**Solution:**
```powershell
# Enable exponential backoff
Send-AzMonitorData `
    -DceEndpoint $dce `
    -DcrImmutableId $dcr `
    -StreamName $stream `
    -Data $data `
    -ThrottleOnFailure `
    -RetryAttempts 5
```

### Private Endpoint Issues

#### DNS not resolving to private IP

```powershell
# Check DNS resolution
Resolve-DnsName dce-prod-abc.eastus-1.ingest.monitor.azure.com

# Should return private IP (10.x.x.x)
# If not, verify:
# 1. Private DNS zone exists: privatelink.monitor.azure.com
# 2. DNS zone linked to VNet
# 3. A record exists for DCE
```

#### Connection timeout

```powershell
# Test connectivity
Test-NetConnection -ComputerName dce-prod-abc.eastus-1.ingest.monitor.azure.com -Port 443

# If fails, check:
# 1. NSG rules allow outbound HTTPS (443)
# 2. Private endpoint is "Approved"
# 3. Firewall rules
```

## Best Practices

### 1. Use Managed Identity When Possible

Managed Identities eliminate the need to manage credentials:

```powershell
# Preferred for Azure resources
Connect-AzMonitorIngestion -UseManagedIdentity
```

### 2. Store Configuration Securely

Use Azure Automation Variables, Key Vault, or environment variables:

```powershell
# Azure Automation
$dce = Get-AutomationVariable -Name 'DCE_Endpoint'

# Environment variables
$dce = $env:DCE_ENDPOINT

# Key Vault
$dce = (Get-AzKeyVaultSecret -VaultName "kv-prod" -Name "DCE-Endpoint").SecretValueText
```

### 3. Implement Proper Error Handling

Always use try/catch and check results:

```powershell
try {
    $result = Send-AzMonitorData -DceEndpoint $dce -DcrImmutableId $dcr -StreamName $stream -Data $data
    
    if (-not $result.Success) {
        Write-Warning "Partial failure: $($result.FailedSends) records failed"
        # Implement alerting or logging
    }
}
catch {
    Write-Error "Critical failure: $_"
    # Implement alerting
}
```

### 4. Use Appropriate Batch Sizes

Balance performance and reliability:

```powershell
# Small batches (100-500): More reliable, slower
# Medium batches (500-1000): Good balance (default)
# Large batches (1000-5000): Faster, risk of timeout

Send-AzMonitorData `
    -Data $data `
    -BatchSize 1000  # Adjust based on your needs
```

### 5. Monitor Your Ingestion

Track ingestion success/failure:

```powershell
$result = Send-AzMonitorData -DceEndpoint $dce -DcrImmutableId $dcr -StreamName $stream -Data $data

# Log results
$logEntry = [PSCustomObject]@{
    Timestamp       = Get-Date
    TotalRecords    = $result.TotalRecords
    SuccessfulSends = $result.SuccessfulSends
    FailedSends     = $result.FailedSends
    Success         = $result.Success
}

$logEntry | Export-Csv -Path "ingestion-log.csv" -Append -NoTypeInformation
```

## Architecture

### How It Works

```
Your Script
    ↓
AzMonitorIngestion Module
    ↓ (calls)
Connect-AzMonitorIngestion
    ↓ (uses)
Az.Accounts Module
    ↓ (gets)
Azure AD Token (JWT)
    ↓ (used in)
Send-AzMonitorData
    ↓ (calls)
Azure Monitor Logs Ingestion API
    ↓ (through)
Data Collection Endpoint (DCE)
    ↓ (validated by)
Data Collection Rule (DCR)
    ↓ (written to)
Log Analytics Workspace
    ↓
Custom Table
```

### Token Scope

The module acquires tokens with the scope `https://monitor.azure.com/.default`

**NOT** `https://graph.microsoft.com/.default` (Graph API - different!)

### Permission Model

Uses **Azure RBAC** on the Data Collection Rule, NOT consent-based API permissions.

- No API permissions required in App Registration
- No admin consent required
- Direct role assignment on Azure resource (DCR)

## API Details

### Endpoint Format

```
https://{dce-name}.{region}-1.ingest.monitor.azure.com/dataCollectionRules/{dcr-immutable-id}/streams/{stream-name}?api-version=2023-01-01
```

### Request Format

```http
POST /dataCollectionRules/{dcrImmutableId}/streams/{streamName}?api-version=2023-01-01
Host: dce-prod-abc.eastus-1.ingest.monitor.azure.com
Authorization: Bearer {azure-ad-token}
Content-Type: application/json

[
  {
    "TimeGenerated": "2024-11-02T12:00:00.000Z",
    "FieldName1": "value1",
    "FieldName2": 123
  }
]
```

### Response

**Success:** HTTP 204 No Content

**Failure:** HTTP 4xx/5xx with JSON error details

## Contributing

Contributions are welcome! Please ensure:
- Code follows PowerShell best practices
- All functions include comment-based help
- Changes are tested with multiple auth methods
- Module version is incremented appropriately

## License

This module is provided as-is for use within your organization.

## Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review Azure Monitor service health: https://status.azure.com
3. Consult Azure Monitor documentation: https://docs.microsoft.com/azure/azure-monitor/

## Version History

### 1.0.0 (Initial Release)
- Multiple authentication methods
- Automatic batching and retry logic
- Diagnostic tools
- Comprehensive error handling
- Production-ready features

## Related Resources

- [Azure Monitor Documentation](https://docs.microsoft.com/azure/azure-monitor/)
- [Logs Ingestion API](https://docs.microsoft.com/azure/azure-monitor/logs/logs-ingestion-api-overview)
- [Data Collection Rules](https://docs.microsoft.com/azure/azure-monitor/essentials/data-collection-rule-overview)
- [Az.Accounts Module](https://docs.microsoft.com/powershell/module/az.accounts/)
