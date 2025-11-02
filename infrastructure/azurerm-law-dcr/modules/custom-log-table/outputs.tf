# Output the table name
output "table_name" {
  description = "Name of the custom table"
  value       = azapi_resource.custom_table.name
}

# Output the table ID
output "table_id" {
  description = "Resource ID of the custom table"
  value       = azapi_resource.custom_table.id
}

# Output the DCR resource ID
output "dcr_id" {
  description = "Resource ID of the Data Collection Rule"
  value       = azurerm_monitor_data_collection_rule.main.id
}

# Output the DCR immutable ID (used for data ingestion)
output "dcr_immutable_id" {
  description = "Immutable ID of the Data Collection Rule (use this for data ingestion API)"
  value       = azurerm_monitor_data_collection_rule.main.immutable_id
}

# Output the stream name
output "stream_name" {
  description = "Stream name for data ingestion"
  value       = "Custom-${var.table_name}"
}

# Output the DCR endpoint
output "data_collection_endpoint_id" {
  description = "Data Collection Endpoint ID used by this DCR"
  value       = var.data_collection_endpoint_id
}
