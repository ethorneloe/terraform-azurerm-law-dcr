# CI Test Outputs
output "dcr_immutable_id" {
  description = "DCR Immutable ID for data ingestion"
  value       = module.ci_test_table.dcr_immutable_id
}

output "stream_name" {
  description = "Stream name for data ingestion"
  value       = module.ci_test_table.stream_name
}

output "dce_logs_ingestion_endpoint" {
  description = "DCE logs ingestion endpoint URL"
  value       = var.dce_name != null ? data.azurerm_monitor_data_collection_endpoint.main[0].logs_ingestion_endpoint : null
}

output "table_name" {
  description = "Name of the test table"
  value       = module.ci_test_table.table_name
}

output "law_id" {
  description = "Log Analytics Workspace ID"
  value       = local.law_id
}

output "law_name" {
  description = "Log Analytics Workspace name"
  value       = var.law_name
}

output "law_resource_group" {
  description = "Log Analytics Workspace resource group"
  value       = var.law_resource_group_name
}
