# Grafana Dashboards for Custom Log Tables
# These dashboards visualize data from the custom tables in Log Analytics
# Dashboards are only deployed if a Grafana workspace is configured

# Conditional Access & Sign-ins Dashboard
module "conditional_access_dashboard" {
  count  = var.grafana_name != null && var.deploy_grafana_dashboards ? 1 : 0
  source = "./modules/grafana-dashboard"

  dashboard_name = "conditional-access-dashboard"
  grafana_id     = local.grafana_id
  dashboard_json = file("${path.module}/dashboards/conditional_access_dashboard.json")

  tags = merge(local.common_tags, {
    Purpose    = "Conditional Access & Sign-in Monitoring"
    DataSource = "ConditionalAccessSignIns_CL"
    Category   = "Security"
  })

  depends_on = [
    module.conditional_access_signins
  ]
}

# ============================================================================
# Example Dashboards (commented out - for reference only)
# Uncomment if you want to deploy dashboards for the example tables
# ============================================================================

# # Application Metrics Dashboard (Example)
# module "app_metrics_dashboard" {
#   count  = var.grafana_name != null && var.deploy_grafana_dashboards ? 1 : 0
#   source = "./modules/grafana-dashboard"
#
#   dashboard_name = "app-metrics-dashboard"
#   grafana_id     = local.grafana_id
#   dashboard_json = file("${path.module}/dashboards/app_metrics_dashboard.json")
#
#   tags = merge(local.common_tags, {
#     Purpose    = "Application Metrics Visualization"
#     DataSource = "AppMetrics_CL"
#   })
#
#   depends_on = [
#     module.app_metrics
#   ]
# }
#
# # Security Events Dashboard (Example)
# module "security_events_dashboard" {
#   count  = var.grafana_name != null && var.deploy_grafana_dashboards ? 1 : 0
#   source = "./modules/grafana-dashboard"
#
#   dashboard_name = "security-events-dashboard"
#   grafana_id     = local.grafana_id
#   dashboard_json = file("${path.module}/dashboards/security_events_dashboard.json")
#
#   tags = merge(local.common_tags, {
#     Purpose    = "Security Events Visualization"
#     DataSource = "SecurityEvents_CL"
#   })
#
#   depends_on = [
#     module.security_events
#   ]
# }
