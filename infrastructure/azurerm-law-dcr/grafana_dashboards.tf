# Grafana Dashboards for Conditional Access Custom Tables
# These dashboards visualize data from the custom tables in Log Analytics
# Dashboards are only deployed if a Grafana workspace is configured

# Conditional Access Policies Dashboard
module "conditional_access_policies_dashboard" {
  count  = var.grafana_name != null && var.deploy_grafana_dashboards ? 1 : 0
  source = "./modules/grafana-dashboard"

  dashboard_name = "conditional-access-policies-dashboard"
  dashboard_json = file("${path.module}/dashboards/conditional_access_policies_dashboard.json")

  tags = merge(local.common_tags, {
    Purpose    = "Conditional Access Policy Monitoring"
    DataSource = "ConditionalAccessPolicies_CL"
    Category   = "Security"
  })

  depends_on = [
    module.conditional_access_policies_table
  ]
}

# Conditional Access Named Locations Dashboard
module "conditional_access_named_locations_dashboard" {
  count  = var.grafana_name != null && var.deploy_grafana_dashboards ? 1 : 0
  source = "./modules/grafana-dashboard"

  dashboard_name = "conditional-access-named-locations-dashboard"
  dashboard_json = file("${path.module}/dashboards/conditional_access_named_locations_dashboard.json")

  tags = merge(local.common_tags, {
    Purpose    = "Conditional Access Named Locations Monitoring"
    DataSource = "ConditionalAccessNamedLocations_CL"
    Category   = "Security"
  })

  depends_on = [
    module.conditional_access_named_locations_table
  ]
}

# ============================================================================
# Example Dashboards (included as templates - not deployed by default)
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
