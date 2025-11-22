# Azure Managed Grafana Dashboards

This directory includes support for deploying Grafana dashboards to visualize data from your custom Log Analytics tables using Azure Managed Grafana.

## Overview

Azure Managed Grafana is a fully managed service for analytics and monitoring that provides a Grafana experience optimized for Azure. The Grafana dashboards in this repository are designed to work with the new Grafana preview feature that integrates with Azure Monitor metrics and Log Analytics workspace custom tables.

## Features

- **Pre-built Dashboards**: Ready-to-use Grafana dashboards for each custom table
- **Azure Monitor Integration**: Seamless integration with Log Analytics using Azure Monitor datasource
- **Infrastructure as Code**: Dashboards deployed via Terraform for consistency
- **Customizable**: JSON-based dashboard definitions that can be easily modified

## Prerequisites

1. **Azure Managed Grafana Workspace**: You need an existing Azure Managed Grafana workspace
   - You can create one via Azure Portal, CLI, or uncomment the Terraform code in `grafana_workspace.tf`
   - Free tier available with Azure Monitor integration

2. **Grafana Permissions**: The Grafana managed identity needs read access to your Log Analytics Workspace
   - Role: `Monitoring Reader` on the Log Analytics Workspace
   - This is automatically configured if you create Grafana via the Terraform code

3. **Data Source Configuration**: Azure Monitor datasource must be configured in Grafana
   - This is typically auto-configured when you create Azure Managed Grafana
   - The datasource connects to your Log Analytics Workspace

## Available Dashboards

### Conditional Access & Sign-ins Dashboard
**File**: `dashboards/conditional_access_dashboard.json`
**Table**: `ConditionalAccessSignIns_CL`
**Data Source**: Entra ID (Azure AD) Sign-in Logs with Conditional Access Policy Evaluation

This comprehensive security dashboard provides deep visibility into your organization's Entra ID (Azure AD) Conditional Access policies and user sign-in activity.

**Key Metrics** (Top Row):
- **Total Sign-ins (24h)**: Overall sign-in volume
- **Failed Sign-ins (24h)**: Failed authentication attempts with thresholds
- **High Risk Sign-ins (24h)**: Sign-ins flagged as high risk by Identity Protection
- **CA Policy Success Rate**: Gauge showing conditional access policy effectiveness

**Trend Analysis**:
- **Sign-ins Over Time (by Status)**: 30-minute interval time series showing success/failure patterns
- **Conditional Access Results**: Donut chart breaking down policy evaluation outcomes (success, failure, notApplied)

**Policy & Risk Monitoring**:
- **Top 10 Conditional Access Policies**: Most frequently evaluated policies
- **Sign-ins by Risk Category**: Distribution across High/Medium/Low/No Risk categories

**User Activity**:
- **Recent Sign-in Events**: Live table with color-coded status and risk indicators showing:
  - TimeGenerated, UserPrincipalName, AppDisplayName
  - IPAddress, Location, Device OS
  - Status, Conditional Access Status, Policy Name
  - Risk Category, MFA Details
- **Top 10 Applications**: Most accessed applications
- **Authentication Methods Used**: Breakdown of auth methods (Password, MFA, Certificate, etc.)

**Geographic & Device Intelligence**:
- **Sign-in Activity Heatmap by Location**: Timeline visualization showing sign-in patterns across locations

**Use Cases**:
- Monitor Conditional Access policy effectiveness
- Identify failed authentication attempts and patterns
- Track high-risk sign-ins requiring investigation
- Analyze MFA adoption and authentication methods
- Detect unusual geographic access patterns
- Audit policy coverage and gaps
- Compliance reporting for security requirements

**Auto-refresh**: 1 minute
**Default Time Range**: Last 24 hours

---

### Example Dashboards (Available but Not Deployed)

The repository also includes example dashboards that can be used as templates:

#### Application Metrics Dashboard (Example)
**File**: `dashboards/app_metrics_dashboard.json` | **Table**: `AppMetrics_CL`
- Time series charts, gauges, summary tables, environment distribution
- Useful template for application performance monitoring

#### Security Events Dashboard (Example)
**File**: `dashboards/security_events_dashboard.json` | **Table**: `SecurityEvents_CL`
- Event statistics, severity visualizations, IP/user tracking
- Useful template for general security event monitoring

To deploy these example dashboards, uncomment the relevant module blocks in `grafana_dashboards.tf` and ensure the corresponding custom tables are created.

## Configuration

### Option 1: Use Existing Grafana Workspace (Recommended)

Update your `.tfvars` file:

```hcl
# Azure Managed Grafana Configuration
grafana_name                = "grafana-dev-001"
grafana_resource_group_name = "rg-monitoring-dev"
deploy_grafana_dashboards   = true
```

### Option 2: Create New Grafana Workspace

Uncomment the resource block in `grafana_workspace.tf`:

```hcl
resource "azurerm_dashboard_grafana" "main" {
  name                = "grafana-${var.environment}"
  resource_group_name = local.rg_name
  location            = local.location
  sku                 = "Standard"
  # ... rest of configuration
}
```

### Option 3: Skip Grafana Dashboards

Leave the Grafana variables unset or set to `null`:

```hcl
grafana_name = null
# OR simply don't set the variable at all
```

## Deployment

### Deploy Everything (Tables + Dashboards)

```bash
cd infrastructure/azurerm-law-dcr
terraform init
terraform plan -var-file="env/dev/dev.tfvars"
terraform apply -var-file="env/dev/dev.tfvars"
```

### Deploy Only Dashboards (Tables Already Exist)

If your custom tables are already deployed and you only want to add/update dashboards:

```bash
terraform apply -var-file="env/dev/dev.tfvars" \
  -target=module.app_metrics_dashboard \
  -target=module.security_events_dashboard
```

## Accessing Dashboards

After deployment:

1. Navigate to your Azure Managed Grafana workspace in the Azure Portal
2. Click "Endpoint" to open Grafana
3. Go to Dashboards → Browse
4. Find your dashboards:
   - **Application Metrics Dashboard**
   - **Security Events Dashboard**

Or use the direct URLs from Terraform outputs:
```bash
terraform output app_metrics_dashboard_id
terraform output security_events_dashboard_id
```

## Dashboard Variables

Each dashboard includes template variables for flexibility:

- **datasource**: Select Azure Monitor datasource
- **workspace**: Select Log Analytics Workspace

These are auto-populated in Grafana and can be changed via the dashboard UI.

## Customizing Dashboards

### Modify Existing Dashboards

1. Edit the JSON file in `dashboards/` directory:
   - `app_metrics_dashboard.json`
   - `security_events_dashboard.json`

2. Update queries, visualizations, or layouts as needed

3. Re-apply Terraform:
   ```bash
   terraform apply -var-file="env/dev/dev.tfvars"
   ```

### Create New Dashboards

1. **Option A: Export from Grafana UI**
   - Design your dashboard in Grafana
   - Export as JSON (Dashboard Settings → JSON Model)
   - Save to `dashboards/your_dashboard.json`

2. **Option B: Create JSON manually**
   - Use existing dashboards as templates
   - Modify queries to match your custom table

3. **Add Terraform configuration**:

Create a new file like `grafana_your_dashboard.tf`:

```hcl
module "your_custom_dashboard" {
  count  = var.grafana_name != null && var.deploy_grafana_dashboards ? 1 : 0
  source = "./modules/grafana-dashboard"

  dashboard_name = "your-custom-dashboard"
  grafana_id     = local.grafana_id
  dashboard_json = file("${path.module}/dashboards/your_dashboard.json")

  tags = merge(local.common_tags, {
    Purpose    = "Your Custom Visualization"
    DataSource = "YourTable_CL"
  })

  depends_on = [
    module.your_custom_table
  ]
}
```

4. **Add output** in `outputs.tf`:

```hcl
output "your_custom_dashboard_id" {
  description = "Grafana dashboard ID for Your Custom Dashboard"
  value       = var.grafana_name != null && var.deploy_grafana_dashboards ? module.your_custom_dashboard[0].dashboard_id : null
}
```

## Query Language (KQL)

Dashboards use Kusto Query Language (KQL) to query Log Analytics. Example queries for Conditional Access data:

### Time Series - Sign-ins Over Time
```kql
ConditionalAccessSignIns_CL
| where TimeGenerated > ago(24h)
| summarize count() by bin(TimeGenerated, 30m), Status
| render timechart
```

### Aggregations - Policy Effectiveness
```kql
ConditionalAccessSignIns_CL
| where TimeGenerated > ago(24h)
| where ConditionalAccessStatus != "notApplied"
| summarize Count = count() by PolicyName, PolicyResult
| order by Count desc
```

### Filtering - High Risk Sign-ins
```kql
ConditionalAccessSignIns_CL
| where RiskCategory == "High Risk"
| where TimeGenerated > ago(1h)
| project TimeGenerated, UserPrincipalName, AppDisplayName, IPAddress, Location, RiskLevel, Status
| order by TimeGenerated desc
```

### Advanced - Failed MFA with Conditional Access
```kql
ConditionalAccessSignIns_CL
| where TimeGenerated > ago(24h)
| where Status == "failure"
| where MfaDetail != ""
| summarize FailureCount = count() by UserPrincipalName, FailureReason, Location
| order by FailureCount desc
| limit 20
```

### Complex - Policy Coverage Analysis
```kql
ConditionalAccessSignIns_CL
| where TimeGenerated > ago(7d)
| summarize
    TotalSignIns = count(),
    Covered = countif(ConditionalAccessStatus != "notApplied"),
    Success = countif(ConditionalAccessStatus == "success"),
    Failed = countif(ConditionalAccessStatus == "failure")
    by AppDisplayName
| extend CoveragePercent = (Covered * 100.0) / TotalSignIns
| extend SuccessRate = (Success * 100.0) / Covered
| where TotalSignIns > 10
| order by CoveragePercent asc
```

## Troubleshooting

### Dashboard Not Appearing

1. **Check Grafana workspace exists**:
   ```bash
   az grafana show --name grafana-dev-001 --resource-group rg-monitoring-dev
   ```

2. **Verify datasource configuration**:
   - Open Grafana → Configuration → Data Sources
   - Ensure Azure Monitor datasource exists and is connected

3. **Check permissions**:
   ```bash
   # Verify Grafana managed identity has Monitoring Reader role
   az role assignment list --scope <law-resource-id> --assignee <grafana-identity-id>
   ```

### No Data in Dashboard

1. **Verify custom tables have data**:
   ```kql
   ConditionalAccessSignIns_CL
   | take 10
   ```

2. **Check time range** in dashboard (default is last 24 hours for Conditional Access dashboard)

3. **Verify workspace variable** is set correctly in dashboard

4. **Ensure data is being ingested**: Check that sign-in data is actively being sent to the custom table

### Dashboard Shows Errors

1. **Query errors**: Check KQL syntax in panel queries
2. **Permission errors**: Ensure Grafana identity has `Monitoring Reader` role
3. **Datasource errors**: Verify Azure Monitor datasource is properly configured

## Best Practices

1. **Dashboard Organization**:
   - One dashboard per custom table or logical grouping
   - Use folders in Grafana for organization
   - Tag dashboards appropriately

2. **Query Optimization**:
   - Use appropriate time ranges (avoid queries > 30 days)
   - Add `| limit` clauses for large result sets
   - Use `summarize` instead of raw data when possible

3. **Version Control**:
   - Keep dashboard JSON in version control
   - Make changes via code, not just Grafana UI
   - Document significant changes in commit messages

4. **Performance**:
   - Set reasonable refresh intervals (30s-5m)
   - Use dashboard variables for flexibility
   - Pre-aggregate data in custom tables when possible

## Azure Managed Grafana Pricing

- **Free tier**: Available with Azure Monitor integration
- **Standard tier**: Required for advanced features
- **Costs**: Based on active users and data processed
- See: [Azure Managed Grafana Pricing](https://azure.microsoft.com/pricing/details/managed-grafana/)

## Resources

- [Azure Managed Grafana Documentation](https://learn.microsoft.com/azure/managed-grafana/)
- [Grafana Dashboard JSON Model](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/view-dashboard-json-model/)
- [Azure Monitor Data Source for Grafana](https://grafana.com/docs/grafana/latest/datasources/azure-monitor/)
- [Kusto Query Language (KQL) Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)

## Support

For issues or questions:
- Review the main [README.md](README.md) for general setup
- Check [Azure Monitor Custom Logs Documentation](https://learn.microsoft.com/azure/azure-monitor/logs/logs-ingestion-api-overview)
- Consult Grafana documentation for dashboard customization
