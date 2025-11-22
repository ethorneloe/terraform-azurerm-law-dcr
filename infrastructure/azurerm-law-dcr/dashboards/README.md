# Grafana Dashboards for Azure Monitor

This directory contains Grafana dashboard JSON files for visualizing Conditional Access data from Log Analytics custom tables.

## Available Dashboards

1. **conditional_access_policies_dashboard.json**
   - Visualizes ConditionalAccessPolicies_CL table data
   - Shows policy metrics, state distribution, authentication controls, and trends

2. **conditional_access_named_locations_dashboard.json**
   - Visualizes ConditionalAccessNamedLocations_CL table data
   - Shows location metrics, trust status, countries, and IP ranges

## Using with Azure Monitor Grafana Dashboards (Preview)

### Prerequisites

- Log Analytics workspace with custom tables deployed
- Data Collection Rules actively ingesting Conditional Access data
- Access to Azure Portal

### Import Steps

1. **Navigate to Azure Monitor Grafana**
   - Go to [Azure Portal](https://portal.azure.com)
   - Navigate to your **Log Analytics workspace**
   - In the left sidebar, select **Monitoring** → **Dashboards (preview)** → **Grafana**

2. **Import Dashboard**
   - Click the **+** icon or **New** → **Import**
   - Click **Upload JSON file**
   - Select one of the JSON files from this directory
   - Click **Load**

3. **Configure Data Source**
   - Select your **Log Analytics workspace** from the data source dropdown
   - Ensure it matches the workspace where your custom tables are deployed
   - Click **Import**

4. **Verify**
   - The dashboard should load with your Conditional Access data
   - Check that all panels display data correctly
   - Default time range: Last 7 days
   - Auto-refresh: 5 minutes

### Customizing Dashboards

After importing, you can:
- Modify time ranges
- Edit panel queries
- Add new visualizations
- Adjust refresh intervals
- Save as a new dashboard

### Troubleshooting

**No data displayed:**
- Verify custom tables have data: Run `ConditionalAccessPolicies_CL | take 10` in Log Analytics
- Check time range includes periods with data ingestion
- Ensure Data Collection Rules are active

**Cannot find Grafana preview:**
- Grafana dashboards preview must be enabled for your subscription
- Check proper permissions to access Log Analytics workspace
- Feature may not be available in all regions yet

## Future IaC Support

Currently, the Azure Monitor Grafana dashboards preview feature requires manual import via the Azure Portal.

When Microsoft releases Terraform/API support for this preview feature, we will update this repository with Infrastructure as Code deployment capabilities.

## Dashboard Queries

All dashboards use Kusto Query Language (KQL) to query Log Analytics custom tables. The queries are designed to:
- Work with the ConditionalAccessPolicies_CL and ConditionalAccessNamedLocations_CL schemas
- Filter data based on selected time ranges
- Handle null/missing values gracefully
- Aggregate metrics for visualization

## References

- [Azure Monitor Grafana Dashboards Documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/visualize-use-grafana-dashboards)
- [Grafana Dashboard JSON Model](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/view-dashboard-json-model/)
- [Kusto Query Language (KQL) Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
