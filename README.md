# Azure Log Analytics Custom Tables with Data Collection Rules (Terraform Module)

A **reusable Terraform module** for creating Azure Log Analytics custom tables with Data Collection Rules (DCRs) using the modern Azure Monitor Logs Ingestion API. Deploy production-ready custom log tables with schema validation, retention policies, and optional KQL transformations.

## Overview

This repository provides infrastructure-as-code for implementing the **Azure Monitor Logs Ingestion API pattern** with:

- **Custom Log Analytics Tables** with user-defined schemas
- **Data Collection Rules (DCRs)** for schema validation and routing
- **Data Collection Endpoints (DCEs)** for secure HTTPS ingestion
- **PowerShell ingestion module** for sending data to custom tables
- **RBAC configuration** for least-privilege access

### Modern Azure Monitor Ingestion Pattern

This solution uses the **Azure Monitor Logs Ingestion API** - the modern replacement for the deprecated HTTP Data Collector API.

**Old Pattern (Deprecated)**:
```
Script → Shared Key Auth → HTTP Data Collector API → Log Analytics
```

**New Pattern (This Repo)**:
```
Script → OAuth2/JWT → DCE → DCR (validate/transform) → Custom Table
```

**Key Advantages**:
- ✅ **Schema validation** at ingestion time (catch errors early)
- ✅ **Azure AD authentication** (no shared secrets to manage)
- ✅ **KQL transformations** in DCR (enrich/filter data before storage)
- ✅ **Private endpoint support** (secure network isolation)
- ✅ **Better error handling** (detailed HTTP status codes and messages)
- ✅ **Flexible retention** (hot + archive tier support)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Data Source (Any)                                     │
│  • PowerShell scripts                                  │
│  • Azure Functions                                     │
│  • Logic Apps                                          │
│  • Custom applications                                 │
└──────────────────┬──────────────────────────────────────┘
                   │
                   │ HTTPS POST with OAuth2 JWT token
                   │ Authorization: Bearer <token>
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│  Data Collection Endpoint (DCE)                        │
│  • Azure-managed HTTPS endpoint                        │
│  • Validates authentication                            │
│  • Regional endpoints for low latency                  │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│  Data Collection Rule (DCR)                            │
│  • Validates schema (rejects invalid data)             │
│  • Applies KQL transformations (optional)              │
│  • Routes to target table                              │
│  • RBAC boundary (Monitoring Metrics Publisher)        │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│  Log Analytics Workspace                               │
│  Custom Table: YourTable_CL                            │
│  • User-defined schema (string, int, datetime, etc.)   │
│  • Flexible retention (hot + archive)                  │
│  • KQL query interface                                 │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│  Query & Visualization                                 │
│  • Azure Monitor Workbooks                             │
│  • Grafana dashboards                                  │
│  • PowerShell analytics                                │
│  • Power BI reports                                    │
│  • API queries via REST                                │
└─────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
terraform-azurerm-law-dcr/
├── infrastructure/
│   └── azurerm-law-dcr/
│       ├── main.tf                              # Core infrastructure
│       ├── modules/
│       │   └── custom-log-table/                # 🎯 Reusable module
│       │       ├── main.tf                      #    Creates table + DCR
│       │       ├── variables.tf                 #    Module inputs
│       │       ├── outputs.tf                   #    DCR IDs, stream names
│       │       └── versions.tf                  #    Provider requirements
│       │
│       └── conditional_access_*.tf              # Example: CA implementation
│
├── PowerShell/
│   ├── modules/
│   │   └── AzMonitorIngestion/                  # 🎯 PowerShell ingestion module
│   │       └── AzMonitorIngestion.psm1          #    REST API wrapper
│   │
│   └── Send-ConditionalAccessToLogAnalytics.ps1 # Example: CA data collector
│
└── docs/
    └── CONDITIONAL-ACCESS-KQL-LIBRARY.md        # Example: CA queries
```

---

## Core Module: `custom-log-table`

The heart of this repository is the **reusable Terraform module** at [infrastructure/azurerm-law-dcr/modules/custom-log-table/](infrastructure/azurerm-law-dcr/modules/custom-log-table/).

### What It Creates

1. **Custom Log Analytics Table** (`_CL` suffix)
   - User-defined schema with typed columns
   - Analytics or Basic plan
   - Configurable retention (hot + archive tiers)

2. **Data Collection Rule (DCR)**
   - Stream declaration (input schema)
   - Data flow configuration
   - Optional KQL transformation
   - Linked to DCE (if provided)

### Module Interface

#### Inputs

```hcl
module "custom_table" {
  source = "./modules/custom-log-table"

  # Required: Table configuration
  table_name = "MyCustomData_CL"  # Must end with _CL

  # Required: Schema definition
  schema = {
    name = "MyCustomData_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime", description = "Timestamp" },
      { name = "ServerName",    type = "string",   description = "Server name" },
      { name = "CpuPercent",    type = "int",      description = "CPU usage %" },
      { name = "MemoryGB",      type = "real",     description = "Memory in GB" },
      { name = "Tags",          type = "dynamic",  description = "JSON tags" },
    ]
  }

  # Required: Log Analytics Workspace
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location

  # Optional: Data Collection Endpoint
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.main.id

  # Optional: Retention configuration
  table_plan              = "Analytics"  # or "Basic"
  retention_in_days       = 90           # Hot tier (fast queries)
  total_retention_in_days = 365          # Total (hot + archive)

  # Optional: KQL transformation
  transform_kql = "source | extend ComputedField = CpuPercent * 2"

  # Optional: Tags
  tags = {
    Environment = "Production"
    Purpose     = "Custom Monitoring"
  }
}
```

#### Outputs

```hcl
# Use these outputs for data ingestion
output "dcr_immutable_id" {
  value = module.custom_table.dcr_immutable_id  # Pass to Send-AzMonitorData
}

output "stream_name" {
  value = module.custom_table.stream_name        # Pass to Send-AzMonitorData
}

output "table_name" {
  value = module.custom_table.table_name         # Query this in KQL
}
```

### Supported Column Types

| Type | Description | Example Values |
|------|-------------|----------------|
| `string` | Text data | `"Server01"`, `"Error"` |
| `int` | 32-bit integer | `42`, `-100` |
| `long` | 64-bit integer | `9223372036854775807` |
| `real` | Double-precision float | `3.14159`, `99.9` |
| `datetime` | Timestamp (ISO 8601) | `"2025-12-02T10:30:00Z"` |
| `bool` | Boolean | `true`, `false` |
| `dynamic` | JSON object/array | `{"key": "value"}`, `[1,2,3]` |
| `guid` | UUID | `"12345678-1234-1234-1234-123456789012"` |

### Table Plans

| Plan | Use Case | Cost | Query Performance | Features |
|------|----------|------|-------------------|----------|
| **Analytics** | Complex queries, alerts | Higher | Fast (columnar) | Full KQL, retention up to 12 years |
| **Basic** | High-volume logs | Lower | Good | No alerts, 8-day retention only |

**Recommendation**: Use `Analytics` for monitoring/alerting data, `Basic` for verbose logs.

---

## PowerShell Ingestion Module: `AzMonitorIngestion`

A custom PowerShell module at [PowerShell/modules/AzMonitorIngestion/](PowerShell/modules/AzMonitorIngestion/) that wraps the Azure Monitor Logs Ingestion REST API.

### Why a Custom Module?

**No official Microsoft module exists** for the Logs Ingestion API. This module provides:

- **Multiple authentication methods** (Managed Identity, Service Principal, Az PowerShell, Az CLI)
- **Automatic JWT token handling** (OAuth2 for `https://monitor.azure.com`)
- **Intelligent batching** (splits large datasets into 1000-record chunks)
- **Retry logic** (exponential backoff for 429/500/502/503/504 errors)
- **Comprehensive diagnostics** (connectivity tests, permission validation)

### Module Functions

```powershell
# 1. Authenticate to Azure Monitor
Connect-AzMonitorIngestion -UseManagedIdentity
Connect-AzMonitorIngestion -UseCurrentContext
Connect-AzMonitorIngestion -UseAzureCli

# 2. Send data to custom table
Send-AzMonitorData `
    -DceEndpoint "https://dce-prod.region.ingest.monitor.azure.com" `
    -DcrImmutableId "dcr-abc123def456..." `
    -StreamName "Custom-MyData_CL" `
    -Data $arrayOfObjects `
    -Verbose

# 3. Diagnostics
Test-AzMonitorIngestion -DceEndpoint $dceUrl
Test-AzMonitorPermissions -DcrResourceId $dcrId -PrincipalId $principalId
Get-AzMonitorModuleInfo
```

### Authentication Methods

```powershell
# Azure Automation / Azure VM (Managed Identity)
Connect-AzMonitorIngestion -UseManagedIdentity

# Local development (existing Az session)
Connect-AzAccount
Connect-AzMonitorIngestion -UseCurrentContext

# Local development (Azure CLI)
az login
Connect-AzMonitorIngestion -UseAzureCli

# Service Principal with certificate
Connect-AzMonitorIngestion `
    -ServicePrincipalCertificate `
    -TenantId "tenant-id" `
    -ApplicationId "app-id" `
    -CertificateThumbprint "ABC123..."

# Service Principal with secret
$secret = ConvertTo-SecureString "secret" -AsPlainText -Force
Connect-AzMonitorIngestion `
    -TenantId "tenant-id" `
    -ApplicationId "app-id" `
    -ServicePrincipalSecret $secret
```

---

## Quick Start Guide

### Step 1: Define Your Custom Table

Create a new Terraform file (e.g., `my_custom_table.tf`):

```hcl
# infrastructure/azurerm-law-dcr/my_custom_table.tf

module "my_custom_table" {
  source = "./modules/custom-log-table"

  table_name = "ServerMetrics_CL"

  schema = {
    name = "ServerMetrics_CL"
    columns = [
      # Required: Every table needs TimeGenerated
      { name = "TimeGenerated", type = "datetime", description = "Collection timestamp" },

      # Your custom columns
      { name = "ServerName",    type = "string",   description = "Server hostname" },
      { name = "Environment",   type = "string",   description = "prod/dev/test" },
      { name = "CpuPercent",    type = "real",     description = "CPU utilization %" },
      { name = "MemoryUsedGB",  type = "real",     description = "Memory used in GB" },
      { name = "DiskIOPS",      type = "long",     description = "Disk I/O operations" },
      { name = "IsHealthy",     type = "bool",     description = "Health check status" },
      { name = "Tags",          type = "dynamic",  description = "Metadata tags (JSON)" },
    ]
  }

  log_analytics_workspace_id  = local.law_id
  data_collection_endpoint_id = local.dce_id
  resource_group_name         = local.rg_name
  location                    = local.location

  table_plan              = "Analytics"
  retention_in_days       = 90
  total_retention_in_days = 365

  # Pass-through (no transformation)
  transform_kql = "source"

  tags = merge(local.common_tags, {
    Purpose = "Server Performance Monitoring"
  })
}

# Export outputs for data ingestion
output "server_metrics_dcr_id" {
  value = module.my_custom_table.dcr_immutable_id
}

output "server_metrics_stream" {
  value = module.my_custom_table.stream_name
}
```

### Step 2: Deploy Infrastructure

```bash
cd infrastructure/azurerm-law-dcr
terraform init
terraform plan
terraform apply

# Save outputs
terraform output server_metrics_dcr_id
terraform output server_metrics_stream
```

### Step 3: Send Data with PowerShell

```powershell
# Import the ingestion module
Import-Module .\PowerShell\modules\AzMonitorIngestion\AzMonitorIngestion.psm1

# Authenticate
Connect-AzMonitorIngestion -UseCurrentContext

# Prepare data (must match schema)
$data = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        ServerName    = "WEB-01"
        Environment   = "Production"
        CpuPercent    = 45.2
        MemoryUsedGB  = 12.8
        DiskIOPS      = 1250
        IsHealthy     = $true
        Tags          = @{ Region = "East US"; Owner = "IT" }
    },
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        ServerName    = "DB-01"
        Environment   = "Production"
        CpuPercent    = 78.5
        MemoryUsedGB  = 28.3
        DiskIOPS      = 3420
        IsHealthy     = $true
        Tags          = @{ Region = "West US"; Owner = "DBA" }
    }
)

# Send to Log Analytics
Send-AzMonitorData `
    -DceEndpoint "https://dce-prod.australiaeast-1.ingest.monitor.azure.com" `
    -DcrImmutableId "dcr-abc123def456..." `
    -StreamName "Custom-ServerMetrics_CL" `
    -Data $data `
    -Verbose
```

### Step 4: Query Your Data

Wait 1-5 minutes for ingestion, then query in Log Analytics:

```kql
ServerMetrics_CL
| where TimeGenerated > ago(1h)
| where CpuPercent > 70
| project TimeGenerated, ServerName, CpuPercent, MemoryUsedGB, IsHealthy
| order by CpuPercent desc
```

---

## Real-World Example: Conditional Access Monitoring

This repository includes a **complete implementation** for monitoring Microsoft Entra ID Conditional Access policies as a reference example.

### Implementation Files

1. **Terraform Tables**:
   - [conditional_access_policies.tf](infrastructure/azurerm-law-dcr/conditional_access_policies.tf) - 71-column schema
   - [conditional_access_named_locations.tf](infrastructure/azurerm-law-dcr/conditional_access_named_locations.tf) - 9-column schema

2. **PowerShell Data Collector**:
   - [Send-ConditionalAccessToLogAnalytics.ps1](PowerShell/Send-ConditionalAccessToLogAnalytics.ps1) - Reads CA policies from Graph API

3. **KQL Query Library**:
   - [docs/CONDITIONAL-ACCESS-KQL-LIBRARY.md](docs/CONDITIONAL-ACCESS-KQL-LIBRARY.md) - 46 production-ready queries

### Key Learnings from CA Implementation

**Schema Design**:
- Flatten nested objects where possible (`User.Id` → separate column)
- Use `dynamic` type for arrays of objects (e.g., exempted users)
- Include metadata columns (`Created`, `Modified`, `State`)

**KQL Query Patterns**:
- Always use `coalesce(array, dynamic([]))` for null-safe array operations
- Explicit type conversions: `tostring()`, `toint()`, `todouble()`
- Get latest snapshot: `summarize arg_max(TimeGenerated, *) by UniqueId`

**Null-Safety for API Compatibility**:
- Queries working in UI may fail via API
- Protect all dynamic property access
- Test with `Invoke-AzOperationalInsightsQuery`, not just UI

See [docs/QUERY-LIBRARY-STATUS.md](docs/QUERY-LIBRARY-STATUS.md) for detailed test results.

---

## Common Use Cases

### 1. Custom Application Logging

**Scenario**: Centralize logs from distributed applications

```hcl
module "app_logs" {
  source = "./modules/custom-log-table"

  table_name = "ApplicationLogs_CL"
  schema = {
    name = "ApplicationLogs_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "AppName",       type = "string" },
      { name = "Environment",   type = "string" },
      { name = "LogLevel",      type = "string" },  # INFO, WARN, ERROR
      { name = "Message",       type = "string" },
      { name = "Exception",     type = "string" },
      { name = "TraceId",       type = "string" },
      { name = "UserId",        type = "string" },
      { name = "Properties",    type = "dynamic" }, # JSON metadata
    ]
  }
  # ... rest of config
}
```

### 2. Compliance Auditing

**Scenario**: Track configuration changes across Azure resources

```hcl
module "compliance_audit" {
  source = "./modules/custom-log-table"

  table_name = "ComplianceAudit_CL"
  schema = {
    name = "ComplianceAudit_CL"
    columns = [
      { name = "TimeGenerated",    type = "datetime" },
      { name = "ResourceId",       type = "string" },
      { name = "ResourceType",     type = "string" },
      { name = "PolicyName",       type = "string" },
      { name = "ComplianceState",  type = "string" },  # Compliant, NonCompliant
      { name = "LastChecked",      type = "datetime" },
      { name = "ReasonCode",       type = "string" },
      { name = "RemediationSteps", type = "string" },
    ]
  }
  # ... rest of config
}
```

### 3. IoT Device Telemetry

**Scenario**: Ingest time-series data from IoT devices

```hcl
module "iot_telemetry" {
  source = "./modules/custom-log-table"

  table_name = "IoTTelemetry_CL"
  schema = {
    name = "IoTTelemetry_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "DeviceId",      type = "string" },
      { name = "DeviceType",    type = "string" },
      { name = "Temperature",   type = "real" },
      { name = "Humidity",      type = "real" },
      { name = "Pressure",      type = "real" },
      { name = "BatteryLevel",  type = "int" },
      { name = "Location",      type = "dynamic" },  # { lat: 0, lon: 0 }
      { name = "Status",        type = "string" },   # Online, Offline, Error
    ]
  }
  # Use Basic plan for high-volume telemetry
  table_plan = "Basic"
  # ... rest of config
}
```

### 4. Security Events

**Scenario**: Aggregate security events from multiple sources

```hcl
module "security_events" {
  source = "./modules/custom-log-table"

  table_name = "SecurityEvents_CL"
  schema = {
    name = "SecurityEvents_CL"
    columns = [
      { name = "TimeGenerated",  type = "datetime" },
      { name = "EventType",      type = "string" },  # Login, Logout, Failed Auth
      { name = "Severity",       type = "string" },  # Low, Medium, High, Critical
      { name = "SourceIP",       type = "string" },
      { name = "UserName",       type = "string" },
      { name = "TargetResource", type = "string" },
      { name = "Action",         type = "string" },
      { name = "Result",         type = "string" },  # Success, Failure
      { name = "Details",        type = "dynamic" },
    ]
  }
  retention_in_days = 180  # Longer retention for security data
  # ... rest of config
}
```

### 5. Configuration Snapshots

**Scenario**: Track infrastructure configuration over time (like the CA example)

```hcl
module "config_snapshots" {
  source = "./modules/custom-log-table"

  table_name = "ConfigSnapshots_CL"
  schema = {
    name = "ConfigSnapshots_CL"
    columns = [
      { name = "TimeGenerated",   type = "datetime" },
      { name = "ResourceId",      type = "string" },
      { name = "ResourceName",    type = "string" },
      { name = "ResourceType",    type = "string" },
      { name = "Configuration",   type = "dynamic" },  # Full config JSON
      { name = "ConfigHash",      type = "string" },   # SHA256 of config
      { name = "LastModified",    type = "datetime" },
      { name = "LastModifiedBy",  type = "string" },
    ]
  }
  # ... rest of config
}
```

---

## Advanced Features

### KQL Transformations in DCR

Transform data **before** it's stored (reduces storage costs and enables real-time enrichment):

```hcl
module "enriched_logs" {
  source = "./modules/custom-log-table"

  table_name = "EnrichedLogs_CL"
  schema = {
    name = "EnrichedLogs_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "RawMessage",    type = "string" },
      { name = "ParsedLevel",   type = "string" },    # Extracted
      { name = "ParsedModule",  type = "string" },    # Extracted
      { name = "Severity",      type = "int" },       # Computed
    ]
  }

  # Transform: Parse log message and compute severity
  transform_kql = <<-KQL
    source
    | extend ParsedLevel = extract(@"\[(\w+)\]", 1, RawMessage)
    | extend ParsedModule = extract(@"<(\w+)>", 1, RawMessage)
    | extend Severity = case(
        ParsedLevel == "ERROR", 3,
        ParsedLevel == "WARN", 2,
        ParsedLevel == "INFO", 1,
        0
      )
  KQL

  # ... rest of config
}
```

### Filtering in DCR (Reduce Costs)

Only store records that meet criteria:

```hcl
transform_kql = <<-KQL
  source
  | where LogLevel in ("ERROR", "WARN")  # Drop INFO/DEBUG
  | where Environment == "Production"     # Drop non-prod
KQL
```

### Multi-Destination Routing

Route data to multiple destinations (requires manual DCR configuration):

```hcl
# Example: Send critical errors to both Log Analytics and Event Hub
data_flow {
  streams      = ["Custom-AppLogs_CL"]
  destinations = ["destination-log-analytics", "destination-event-hub"]
  transform_kql = "source | where LogLevel == 'ERROR'"
  output_stream = "Custom-AppLogs_CL"
}
```

---

## RBAC and Security

### Required Permissions

**For Data Ingestion** (PowerShell script, Azure Function, etc.):
- **Role**: `Monitoring Metrics Publisher` on the DCR
- **Scope**: DCR resource ID only (not subscription-wide)
- **Grants**: `Microsoft.Insights/DataCollectionRules/Data/Write`

**For Querying Data** (analysts, dashboards):
- **Role**: `Log Analytics Reader` on the workspace
- **Scope**: Workspace or specific tables
- **Grants**: `Microsoft.OperationalInsights/workspaces/query/*/read`

### Assigning Permissions

```bash
# Grant Monitoring Metrics Publisher to Managed Identity
az role assignment create \
  --assignee <managed-identity-object-id> \
  --role "Monitoring Metrics Publisher" \
  --scope "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Insights/dataCollectionRules/dcr-mytable"

# Grant Log Analytics Reader to security team
az role assignment create \
  --assignee <group-object-id> \
  --role "Log Analytics Reader" \
  --scope "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<workspace>"
```

### Security Best Practices

1. **Use Managed Identity** for Azure-hosted scripts (Automation, Functions, VMs)
2. **Scope permissions tightly** (DCR-level, not subscription-level)
3. **Enable Private Endpoints** for DCE and Log Analytics Workspace
4. **Customer-Managed Keys (CMK)** for data encryption at rest
5. **Azure Monitor Private Link Scope** for network isolation
6. **Audit role assignments** regularly with Azure Policy

---

## Cost Optimization

### Pricing Components (Log Analytics)

| Component | Pricing | Notes |
|-----------|---------|-------|
| **Data Ingestion** | ~$2.30/GB | Pay for what you ingest |
| **Hot Tier Retention** | ~$0.12/GB/month | Fast queries (8-730 days) |
| **Archive Tier Retention** | ~$0.025/GB/month | Cheaper storage (90 days to 12 years) |
| **Data Export** | ~$0.13/GB | Export to storage/Event Hub |
| **Basic Logs Ingestion** | ~$0.50/GB | Lower cost, limited features |
| **Search Jobs** | ~$0.005/GB scanned | For archived data |

*Prices approximate (US East, Jan 2025) - check [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)*

### Cost Reduction Strategies

1. **Use Basic Plan for High-Volume Logs**
   ```hcl
   table_plan = "Basic"  # ~78% cheaper ingestion
   ```
   - Good for: Debug logs, verbose telemetry, non-alerting data
   - Limitations: No alerts, 8-day retention only, slower queries

2. **Filter Data in DCR**
   ```hcl
   transform_kql = "source | where Severity in ('ERROR', 'WARN')"
   ```
   - Drops data before storage (no ingestion cost)

3. **Optimize Retention**
   ```hcl
   retention_in_days       = 30   # Keep 30 days hot (not 90)
   total_retention_in_days = 365  # Rest in cheap archive
   ```

4. **Aggregate Before Sending**
   ```powershell
   # Send 1 summary record instead of 100 individual records
   $summary = $rawData | Measure-Object -Property Value -Average -Sum -Maximum
   ```

5. **Sampling for High-Volume Data**
   ```hcl
   transform_kql = "source | sample 10"  # Keep only 10% of records
   ```

### Example Cost Calculation

**Scenario**: 1000 server metrics per hour, 5KB per record

- **Daily ingestion**: `1000 records/hour × 24 hours × 5KB = 120 MB/day = 3.6 GB/month`
- **Monthly cost**:
  - Ingestion: `3.6 GB × $2.30 = $8.28`
  - Hot retention (90 days): `3.6 GB × 3 months × $0.12 = $1.30`
  - Archive (275 days): `3.6 GB × 9 months × $0.025 = $0.81`
  - **Total**: **~$10.40/month**

---

## Troubleshooting

### Data Not Appearing in Log Analytics

**Symptom**: `Send-AzMonitorData` succeeds but no data in table

**Checklist**:
1. **Wait 1-5 minutes** (ingestion latency)
2. **Check table name**: Use `_CL` suffix in queries (`ServerMetrics_CL`, not `ServerMetrics`)
3. **Verify time range**: Use `| where TimeGenerated > ago(1h)` (not `ago(5m)`)
4. **Check DCR resource ID**: Ensure using `dcr_immutable_id` (not `dcr_id`)
5. **Review ingestion logs**: Check Azure Automation job output or PowerShell console

### Permission Errors

**Error**: `403 Forbidden` when sending data

**Solutions**:
```bash
# 1. Verify role assignment exists
az role assignment list \
  --assignee <managed-identity-object-id> \
  --scope <dcr-resource-id>

# 2. Grant Monitoring Metrics Publisher
az role assignment create \
  --assignee <managed-identity-object-id> \
  --role "Monitoring Metrics Publisher" \
  --scope <dcr-resource-id>

# 3. Wait 5-10 minutes for RBAC propagation
```

### Schema Validation Errors

**Error**: `400 Bad Request - Schema validation failed`

**Common causes**:
- Missing `TimeGenerated` column
- Wrong data type (sent `"123"` string for `int` column)
- Extra columns not in schema
- Null values in non-nullable columns

**Solution**:
```powershell
# Ensure data matches schema exactly
$data = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")  # ISO 8601
        ServerName    = "WEB-01"                                     # string
        CpuPercent    = [double]45.2                                 # real
        IsHealthy     = [bool]$true                                  # bool
    }
)
```

### Authentication Failures

**Error**: `Failed to get access token`

**Solutions**:
```powershell
# For Managed Identity: Ensure it's enabled
Get-AzVM -Name $vmName | Select-Object -ExpandProperty Identity

# For Az PowerShell: Re-authenticate
Connect-AzAccount
Connect-AzMonitorIngestion -UseCurrentContext

# For Az CLI: Re-login
az login
Connect-AzMonitorIngestion -UseAzureCli
```

### Connectivity Issues

**Error**: `Unable to connect to DCE endpoint`

**Diagnostic**:
```powershell
# Test DCE connectivity
Test-AzMonitorIngestion -DceEndpoint "https://dce-prod.region.ingest.monitor.azure.com"

# Check DNS resolution
Resolve-DnsName "dce-prod.region.ingest.monitor.azure.com"

# Test HTTPS connectivity
Test-NetConnection -ComputerName "dce-prod.region.ingest.monitor.azure.com" -Port 443
```

---

## Limitations and Considerations

### Azure Monitor Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Max payload size | 1 MB compressed | Module batches automatically |
| Max records per batch | 10,000 | Module uses 1,000 by default |
| Max columns per table | 500 | Rarely hit in practice |
| Max string column length | 2,048 KB | Truncated if exceeded |
| Max dynamic object depth | 64 levels | For nested JSON |
| Max ingestion rate | Varies by plan | Throttled with 429 errors |
| Table name suffix | Must end `_CL` | Custom table requirement |
| TimeGenerated requirement | Mandatory | Every table must have it |

### Terraform Limitations

- **No table deletion**: `azapi_resource` doesn't support `delete` lifecycle - tables must be manually deleted
- **Schema changes**: Adding columns is safe, but changing types requires table recreation
- **DCR updates**: Some properties require DCR deletion and recreation

### PowerShell Module Limitations

- **PowerShell 7+ recommended**: PowerShell 5.1 has limited `ConvertFrom-SecureString` support
- **Large payloads**: Split manually if single records exceed 1 MB
- **Concurrent sends**: Module doesn't implement parallel batching (send sequentially)

---

## Examples and Templates

### Minimal Template

```hcl
# Simplest possible custom table
module "simple_table" {
  source = "./modules/custom-log-table"

  table_name = "SimpleEvents_CL"
  schema = {
    name = "SimpleEvents_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime" },
      { name = "Message",       type = "string" },
    ]
  }

  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = data.azurerm_resource_group.main.location
}
```

### Full-Featured Template

```hcl
# Production-ready configuration
module "production_table" {
  source = "./modules/custom-log-table"

  table_name = "ProductionLogs_CL"

  schema = {
    name = "ProductionLogs_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime", description = "Event timestamp" },
      { name = "EventId",       type = "guid",     description = "Unique event ID" },
      { name = "Severity",      type = "int",      description = "0=Debug, 1=Info, 2=Warn, 3=Error" },
      { name = "Source",        type = "string",   description = "Event source system" },
      { name = "Category",      type = "string",   description = "Event category" },
      { name = "Message",       type = "string",   description = "Event message" },
      { name = "Properties",    type = "dynamic",  description = "Additional properties (JSON)" },
    ]
  }

  log_analytics_workspace_id  = data.azurerm_log_analytics_workspace.main.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.main.id
  resource_group_name         = data.azurerm_resource_group.main.name
  location                    = data.azurerm_resource_group.main.location

  table_plan              = "Analytics"
  retention_in_days       = 90
  total_retention_in_days = 730  # 2 years total

  # Filter: Only store warnings and errors
  transform_kql = "source | where Severity >= 2"

  tags = {
    Environment  = "Production"
    CostCenter   = "IT-Operations"
    ManagedBy    = "Terraform"
    Purpose      = "Application Logging"
    DataOwner    = "platform-team@company.com"
    Compliance   = "SOC2"
  }
}

# Configure RBAC
resource "azurerm_role_assignment" "dcr_publisher" {
  scope                = module.production_table.dcr_id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.ingestion.principal_id
}
```

---

## References

### Microsoft Documentation

- **[Azure Monitor Logs Ingestion API Overview](https://learn.microsoft.com/azure/azure-monitor/logs/logs-ingestion-api-overview)**
- **[Data Collection Rules (DCR)](https://learn.microsoft.com/azure/azure-monitor/essentials/data-collection-rule-overview)**
- **[Custom Tables in Log Analytics](https://learn.microsoft.com/azure/azure-monitor/logs/create-custom-table)**
- **[KQL Query Language Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)**
- **[Log Analytics Pricing](https://azure.microsoft.com/pricing/details/monitor/)**

### Terraform Providers

- **[AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)**
- **[AzAPI Provider](https://registry.terraform.io/providers/Azure/azapi/latest/docs)** (required for custom tables)

### Tools

- **[Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)**
- **[PowerShell Az Module](https://learn.microsoft.com/powershell/azure/install-az-ps)**
- **[Terraform](https://www.terraform.io/downloads)**

---

## Contributing

Contributions welcome! Please consider:

- **New use case examples** (add to repository as reference implementations)
- **Module enhancements** (additional DCR features, multi-region support)
- **Documentation improvements** (clarifications, corrections, additional examples)
- **Bug fixes** (issues with module, PowerShell functions, or examples)

**Contribution guidelines**:
1. Open an issue first to discuss proposed changes
2. Include tests/validation for new features
3. Update documentation for any interface changes
4. Follow existing code style and patterns

---

## License

[MIT License](LICENSE)