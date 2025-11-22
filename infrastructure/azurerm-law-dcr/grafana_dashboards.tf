# Grafana Dashboards for Conditional Access Custom Tables
# These dashboards visualize data from the custom tables in Log Analytics
# Dashboards are only deployed if a Grafana workspace is configured
#
# IMPORTANT: Requires Azure Managed Grafana instance - see grafana_workspace.tf

# Conditional Access Policies Dashboard
module "conditional_access_policies_dashboard" {
  count  = local.deploy_dashboards ? 1 : 0
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
  count  = local.deploy_dashboards ? 1 : 0
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
