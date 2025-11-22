# Output values from the deployment

# Shared infrastructure outputs
output "law_id" {
  description = "Log Analytics Workspace ID"
  value       = local.law_id
}

output "dce_id" {
  description = "Data Collection Endpoint ID (if exists)"
  value       = local.dce_id
}

output "dce_logs_ingestion_endpoint" {
  description = "DCE logs ingestion endpoint URL (required for data ingestion API calls)"
  value       = var.dce_name != null ? data.azurerm_monitor_data_collection_endpoint.main[0].logs_ingestion_endpoint : null
}

output "location" {
  description = "Azure region"
  value       = local.location
}

# Conditional Access Policies table outputs
output "conditional_access_policies_dcr_id" {
  description = "DCR Resource ID for Conditional Access Policies table"
  value       = module.conditional_access_policies_table.dcr_id
}

output "conditional_access_policies_dcr_immutable_id" {
  description = "DCR Immutable ID for Conditional Access Policies (use for data ingestion)"
  value       = module.conditional_access_policies_table.dcr_immutable_id
}

output "conditional_access_policies_stream_name" {
  description = "Stream name for Conditional Access Policies ingestion"
  value       = module.conditional_access_policies_table.stream_name
}

# Conditional Access Named Locations table outputs
output "conditional_access_named_locations_dcr_id" {
  description = "DCR Resource ID for Conditional Access Named Locations table"
  value       = module.conditional_access_named_locations_table.dcr_id
}

output "conditional_access_named_locations_dcr_immutable_id" {
  description = "DCR Immutable ID for Conditional Access Named Locations (use for data ingestion)"
  value       = module.conditional_access_named_locations_table.dcr_immutable_id
}

output "conditional_access_named_locations_stream_name" {
  description = "Stream name for Conditional Access Named Locations ingestion"
  value       = module.conditional_access_named_locations_table.stream_name
}

# Conditional Access Workbook outputs
output "workbook_id" {
  description = "Resource ID of the Conditional Access monitoring workbook"
  value       = azurerm_application_insights_workbook.conditional_access_enhanced.id
}

output "workbook_name" {
  description = "Display name of the Conditional Access monitoring workbook"
  value       = azurerm_application_insights_workbook.conditional_access_enhanced.display_name
}

# Add additional outputs here as you create more custom table files

# Grafana outputs
output "grafana_id" {
  description = "Azure Managed Grafana workspace ID"
  value       = local.grafana_id
}

output "conditional_access_policies_dashboard_id" {
  description = "Grafana dashboard ID for Conditional Access Policies"
  value       = var.grafana_name != null && var.deploy_grafana_dashboards ? module.conditional_access_policies_dashboard[0].dashboard_id : null
}

output "conditional_access_named_locations_dashboard_id" {
  description = "Grafana dashboard ID for Conditional Access Named Locations"
  value       = var.grafana_name != null && var.deploy_grafana_dashboards ? module.conditional_access_named_locations_dashboard[0].dashboard_id : null
}

# Example dashboard outputs (commented out)
# output "app_metrics_dashboard_id" {
#   description = "Grafana dashboard ID for Application Metrics"
#   value       = var.grafana_name != null && var.deploy_grafana_dashboards ? module.app_metrics_dashboard[0].dashboard_id : null
# }
#
# output "security_events_dashboard_id" {
#   description = "Grafana dashboard ID for Security Events"
#   value       = var.grafana_name != null && var.deploy_grafana_dashboards ? module.security_events_dashboard[0].dashboard_id : null
# }
