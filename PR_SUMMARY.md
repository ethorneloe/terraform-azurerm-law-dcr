# Pull Request: Azure Managed Grafana Dashboard Support

## Summary

This PR adds comprehensive support for deploying **Azure Managed Grafana dashboards** to visualize data from custom Log Analytics tables. This provides a modern, feature-rich alternative to Azure Workbooks with better visualization capabilities and infrastructure-as-code deployment.

## What's New

### 🎯 Features Added

1. **Grafana Dashboard Module** (`modules/grafana-dashboard/`)
   - Reusable Terraform module for deploying Grafana dashboards
   - Uses Azure API (azapi provider) for dashboard deployment
   - Supports tagging and dependency management

2. **Pre-built Dashboards** (`dashboards/`)
   - **Application Metrics Dashboard** - Visualizes `AppMetrics_CL` table with:
     - Time series charts for metric trends
     - Active application gauges
     - Metric summary tables
     - Environment distribution

   - **Security Events Dashboard** - Visualizes `SecurityEvents_CL` table with:
     - Real-time event statistics
     - Severity-based visualizations
     - Top source IPs and users
     - Recent events table with color-coded severity
     - Event type distribution

3. **Terraform Integration**
   - `grafana_workspace.tf` - References existing Grafana workspace (with commented option to create new)
   - `grafana_dashboards.tf` - Deploys dashboards conditionally based on configuration
   - Updated variables for Grafana configuration
   - New outputs for dashboard resource IDs

4. **Comprehensive Documentation**
   - `GRAFANA.md` - Complete guide covering:
     - Setup and prerequisites
     - Dashboard descriptions
     - Configuration options
     - Customization guide
     - Troubleshooting
     - Best practices
   - Updated main `README.md` with Grafana section

## Files Changed

### New Files
```
infrastructure/azurerm-law-dcr/
├── grafana_workspace.tf                          # Grafana workspace reference
├── grafana_dashboards.tf                         # Dashboard deployment
├── GRAFANA.md                                    # Comprehensive documentation
├── dashboards/
│   ├── app_metrics_dashboard.json                # Application metrics visualization
│   └── security_events_dashboard.json            # Security events visualization
└── modules/grafana-dashboard/
    ├── main.tf                                   # Dashboard module logic
    ├── variables.tf                              # Module variables
    ├── outputs.tf                                # Module outputs
    └── versions.tf                               # Provider requirements
```

### Modified Files
```
infrastructure/azurerm-law-dcr/
├── variables.tf                                  # Added Grafana variables
├── outputs.tf                                    # Added dashboard outputs
├── README.md                                     # Added Grafana section
└── env/dev/dev.tfvars                           # Example Grafana config
```

## Configuration

### Optional Grafana Deployment

Grafana dashboards are **optional** and only deploy when configured:

```hcl
# In your .tfvars file
grafana_name                = "grafana-dev-001"
grafana_resource_group_name = "rg-monitoring-dev"
deploy_grafana_dashboards   = true
```

### Skip Grafana Deployment

Leave unconfigured or set to `null`:

```hcl
grafana_name = null  # Dashboards will not be deployed
```

## Benefits

### Why Grafana over Workbooks?

1. **Better Visualizations**: More panel types, better time series, advanced charting
2. **Infrastructure as Code**: Dashboard JSON in version control, deployed via Terraform
3. **Modern UI**: Intuitive interface with better user experience
4. **Free with Azure Monitor**: Available in preview at no additional cost
5. **Industry Standard**: Widely adopted open-source solution
6. **Advanced Querying**: Powerful KQL integration with Azure Monitor datasource
7. **Template Variables**: Dynamic dashboards with workspace/datasource selection

## Technical Details

### Dashboard Architecture

- **Datasource**: Azure Monitor (grafana-azure-monitor-datasource)
- **Query Language**: Kusto Query Language (KQL)
- **Deployment**: Azure API via azapi provider
- **Format**: Standard Grafana JSON dashboard format
- **Variables**: Templated for datasource and workspace selection

### Grafana Integration

Dashboards connect to Azure Managed Grafana which:
- Integrates with Log Analytics Workspace
- Uses managed identity with `Monitoring Reader` role
- Supports auto-refresh (30s default)
- Provides real-time data visualization

### Query Examples

Application metrics time series:
```kql
AppMetrics_CL
| where TimeGenerated > ago(1h)
| summarize avg(MetricValue) by bin(TimeGenerated, 5m), MetricName
| render timechart
```

Security events by severity:
```kql
SecurityEvents_CL
| where TimeGenerated > ago(6h)
| summarize count() by bin(TimeGenerated, 5m), SeverityLevel
| render timechart
```

## Testing

### Manual Testing Steps

1. **Syntax Validation**:
   ```bash
   terraform init
   terraform validate
   ```

2. **Plan Review**:
   ```bash
   terraform plan -var-file="env/dev/dev.tfvars"
   ```

3. **Deploy**:
   ```bash
   terraform apply -var-file="env/dev/dev.tfvars"
   ```

4. **Verify Dashboards**:
   - Navigate to Azure Managed Grafana
   - Check dashboards appear in Grafana UI
   - Verify queries return data
   - Test dashboard interactivity

### Prerequisites for Testing

- Azure Managed Grafana workspace (free tier available)
- Grafana managed identity with `Monitoring Reader` role on Log Analytics
- Custom tables with data (AppMetrics_CL, SecurityEvents_CL)

## Backward Compatibility

✅ **Fully backward compatible** - No breaking changes

- Existing configurations work without modification
- Grafana features are opt-in via variables
- Default behavior: Grafana dashboards are not deployed
- No impact on existing custom table deployments

## Migration Path

For users who want to adopt Grafana:

1. **Create/Use Grafana Workspace**:
   ```bash
   az grafana create --name grafana-dev-001 --resource-group rg-monitoring-dev
   ```

2. **Grant Permissions**:
   ```bash
   # Get Grafana managed identity
   GRAFANA_IDENTITY=$(az grafana show --name grafana-dev-001 --resource-group rg-monitoring-dev --query identity.principalId -o tsv)

   # Grant Monitoring Reader role
   az role assignment create --assignee $GRAFANA_IDENTITY --role "Monitoring Reader" --scope <law-resource-id>
   ```

3. **Update tfvars**:
   ```hcl
   grafana_name                = "grafana-dev-001"
   grafana_resource_group_name = "rg-monitoring-dev"
   ```

4. **Deploy**:
   ```bash
   terraform apply -var-file="env/dev/dev.tfvars"
   ```

## Future Enhancements

Potential future work (not in this PR):

- [ ] Additional dashboard examples for common use cases
- [ ] Alert rule definitions in Grafana
- [ ] Dashboard provisioning via Grafana API
- [ ] Multi-workspace dashboard support
- [ ] Grafana workspace creation (currently commented in code)
- [ ] Dashboard template library

## Documentation

Complete documentation provided in:

- **[GRAFANA.md](infrastructure/azurerm-law-dcr/GRAFANA.md)** - Comprehensive Grafana guide
- **[README.md](infrastructure/azurerm-law-dcr/README.md)** - Updated with Grafana section
- **Inline comments** - In all new Terraform files

## Related Resources

- [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/)
- [Grafana Azure Monitor Datasource](https://grafana.com/docs/grafana/latest/datasources/azure-monitor/)
- [KQL Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)

## Author Notes

This implementation follows the existing repository patterns:
- One file per logical component
- Reusable modules
- Environment-specific variables in tfvars
- Comprehensive documentation
- Optional/conditional features

The Grafana dashboards are designed to be easily customizable - users can export from Grafana UI, modify the JSON, and redeploy via Terraform.

---

## Review Checklist

- [x] Code follows existing repository patterns
- [x] Documentation is comprehensive
- [x] Backward compatible (no breaking changes)
- [x] Features are optional/conditional
- [x] Examples provided in tfvars
- [x] Module structure matches existing modules
- [x] Dashboard JSON is valid Grafana format
- [x] Variables properly documented
- [x] Outputs added for new resources
