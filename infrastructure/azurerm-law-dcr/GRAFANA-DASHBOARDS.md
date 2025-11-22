# Grafana Dashboards for Conditional Access Monitoring

This directory contains Grafana dashboard JSON files that can be manually imported into Azure Monitor's free Grafana dashboards preview feature.

## Available Dashboards

The `dashboards/` directory contains the following dashboard JSON files:

1. **conditional_access_policies_dashboard.json** - Visualizes Conditional Access policies data
   - Total, enabled, report-only, and disabled policy metrics
   - Policy state distribution (donut chart)
   - Top 10 authentication controls (bar chart)
   - Comprehensive policies table with all key fields
   - 30-day policy trend analysis

2. **conditional_access_named_locations_dashboard.json** - Visualizes named locations data
   - Total locations and trusted location metrics
   - Trust status distribution (donut chart)
   - Top 10 countries by location count (bar chart)
   - Named locations table with IP ranges and country details

## Prerequisites

Before importing these dashboards, ensure you have:

1. **Log Analytics Workspace** with custom tables deployed:
   - `ConditionalAccessPolicies_CL`
   - `ConditionalAccessNamedLocations_CL`

2. **Data Collection Rules (DCR)** configured and actively ingesting data into the custom tables

3. **Azure Portal access** to your Log Analytics workspace

## How to Import Dashboards

### Step 1: Access Grafana Dashboards Preview

1. Navigate to the [Azure Portal](https://portal.azure.com)
2. Go to your **Log Analytics workspace**
3. In the left sidebar, under **Monitoring**, click on **Dashboards (preview)**
4. Click on **Grafana** or **Open Grafana**

### Step 2: Import Dashboard JSON

1. In the Grafana interface, click the **+** icon in the left sidebar
2. Select **Import dashboard**
3. Click **Upload JSON file** or paste the JSON content directly:
   - For file upload: Select one of the JSON files from the `dashboards/` directory
   - For direct paste: Copy the contents of a JSON file and paste it into the text area
4. Click **Load**

### Step 3: Configure Data Source

1. After loading the JSON, you'll see the import screen
2. For the **Azure Monitor** data source field:
   - Select your Log Analytics workspace from the dropdown
   - This should match the workspace where your custom tables are deployed
3. Click **Import**

### Step 4: Verify Dashboard

1. The dashboard should now load with your Conditional Access data
2. Verify that:
   - All panels are displaying data correctly
   - The time range selector is working (default: last 7 days)
   - The auto-refresh is functioning (default: 5 minutes)

## Customizing Dashboards

After importing, you can customize the dashboards to fit your needs:

### Modify Time Range
- Click the time picker in the top-right corner
- Select a different time range (e.g., Last 24 hours, Last 30 days)
- You can also set a custom absolute time range

### Adjust Auto-Refresh
- Click the refresh interval dropdown (top-right, next to time picker)
- Select a different refresh interval or disable auto-refresh

### Edit Panels
1. Click on a panel title
2. Select **Edit** from the dropdown menu
3. Modify the query, visualization settings, or thresholds as needed
4. Click **Apply** to save changes

### Save Modified Dashboards
- After making changes, click the **Save dashboard** icon (disk icon) in the top-right
- Enter a new name if you want to keep the original dashboard unchanged

## Dashboard Queries

All dashboards use **Kusto Query Language (KQL)** to query data from Log Analytics. The queries are designed to:

- Filter data based on the selected time range
- Aggregate metrics for visualization
- Handle missing or null values gracefully
- Sort results for better readability

### Example Query (Total Policies)
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated >= ago(7d)
| summarize TotalPolicies = dcount(Id)
```

## Troubleshooting

### Dashboard shows "No data"
- Verify that your custom tables have data: Run a test query in Log Analytics
  ```kql
  ConditionalAccessPolicies_CL
  | take 10
  ```
- Check that the time range includes periods when data was ingested
- Ensure your Data Collection Rules are actively collecting data

### Cannot find Grafana Dashboards in Azure Portal
- The Grafana dashboards preview feature must be enabled for your subscription
- Check that you have proper permissions to access the Log Analytics workspace
- Try accessing Grafana directly: `https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/grafana`

### Data source not showing up during import
- Ensure you're importing the dashboard while connected to the correct Azure subscription
- Verify that your Log Analytics workspace is in the same subscription
- Refresh the Grafana page and try importing again

### Queries are slow or timing out
- Consider reducing the time range for large datasets
- Add filters to the queries to reduce data volume
- Check the Log Analytics workspace query performance

## Additional Resources

- [Azure Monitor Grafana documentation](https://learn.microsoft.com/azure/azure-monitor/visualize/grafana-plugin)
- [Grafana dashboard documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Kusto Query Language (KQL) reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
- [Log Analytics custom logs](https://learn.microsoft.com/azure/azure-monitor/logs/logs-ingestion-api-overview)

## Support

For issues related to:
- **Dashboard JSON files**: Check the repository issues or create a new issue
- **Azure Monitor Grafana preview**: Contact Microsoft Support or check Azure documentation
- **Data ingestion**: Review your Data Collection Rules and PowerShell scripts in the `scripts/` directory
