# Grafana Dashboards for Custom Log Tables
# These dashboards visualize data from the custom tables in Log Analytics
# Dashboards are only deployed if a Grafana workspace is configured

# Application Metrics Dashboard
module "app_metrics_dashboard" {
  count  = var.grafana_name != null && var.deploy_grafana_dashboards ? 1 : 0
  source = "./modules/grafana-dashboard"

  dashboard_name = "app-metrics-dashboard"
  grafana_id     = local.grafana_id
  dashboard_json = file("${path.module}/dashboards/app_metrics_dashboard.json")

  tags = merge(local.common_tags, {
    Purpose    = "Application Metrics Visualization"
    DataSource = "AppMetrics_CL"
  })

  depends_on = [
    module.app_metrics
  ]
}

# Security Events Dashboard
module "security_events_dashboard" {
  count  = var.grafana_name != null && var.deploy_grafana_dashboards ? 1 : 0
  source = "./modules/grafana-dashboard"

  dashboard_name = "security-events-dashboard"
  grafana_id     = local.grafana_id
  dashboard_json = file("${path.module}/dashboards/security_events_dashboard.json")

  tags = merge(local.common_tags, {
    Purpose    = "Security Events Visualization"
    DataSource = "SecurityEvents_CL"
  })

  depends_on = [
    module.security_events
  ]
}
