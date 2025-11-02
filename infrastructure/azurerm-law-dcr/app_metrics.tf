# Application Metrics Custom Table + DCR
# This table collects application performance metrics

module "app_metrics" {
  source = "./modules/custom-log-table"

  table_name = "AppMetrics_CL"

  schema = {
    name = "AppMetrics_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime", description = "The time at which the data was generated" },
      { name = "ApplicationName", type = "string", description = "Name of the application" },
      { name = "MetricName", type = "string", description = "Name of the metric" },
      { name = "MetricValue", type = "real", description = "Value of the metric" },
      { name = "Environment", type = "string", description = "Environment name" },
      { name = "HostName", type = "string", description = "Host name" }
    ]
  }

  log_analytics_workspace_id  = local.law_id
  data_collection_endpoint_id = local.dce_id
  resource_group_name         = local.rg_name
  location                    = local.location

  # Basic plan has fixed 8-day retention - do not specify retention parameters
  table_plan = "Basic"

  transform_kql = "source" # No transformation needed

  tags = merge(local.common_tags, {
    Purpose   = "Application Monitoring"
    TableType = "Metrics"
  })
}
