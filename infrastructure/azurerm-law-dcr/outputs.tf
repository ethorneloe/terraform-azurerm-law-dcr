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

# Add additional outputs here as you create more custom table files
