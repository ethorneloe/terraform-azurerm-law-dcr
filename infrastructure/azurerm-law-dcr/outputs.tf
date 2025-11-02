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

# App Metrics table outputs
output "app_metrics_dcr_id" {
  description = "DCR Resource ID for App Metrics table"
  value       = module.app_metrics.dcr_id
}

output "app_metrics_dcr_immutable_id" {
  description = "DCR Immutable ID for App Metrics (use for data ingestion)"
  value       = module.app_metrics.dcr_immutable_id
}

output "app_metrics_stream_name" {
  description = "Stream name for App Metrics ingestion"
  value       = module.app_metrics.stream_name
}

# Security Events table outputs
output "security_events_dcr_id" {
  description = "DCR Resource ID for Security Events table"
  value       = module.security_events.dcr_id
}

output "security_events_dcr_immutable_id" {
  description = "DCR Immutable ID for Security Events (use for data ingestion)"
  value       = module.security_events.dcr_immutable_id
}

output "security_events_stream_name" {
  description = "Stream name for Security Events ingestion"
  value       = module.security_events.stream_name
}

# Add additional outputs here as you create more custom table files
