# Get existing Log Analytics Workspace
data "azurerm_log_analytics_workspace" "main" {
  name                = var.law_name
  resource_group_name = var.law_resource_group_name
}

# Get existing Data Collection Endpoint (if it exists)
data "azurerm_monitor_data_collection_endpoint" "main" {
  count               = var.dce_name != null ? 1 : 0
  name                = var.dce_name
  resource_group_name = var.dce_resource_group_name
}

# Local values for reuse across all custom table modules
locals {
  law_id   = data.azurerm_log_analytics_workspace.main.id
  dce_id   = var.dce_name != null ? data.azurerm_monitor_data_collection_endpoint.main[0].id : null
  location = data.azurerm_log_analytics_workspace.main.location
  rg_name  = data.azurerm_log_analytics_workspace.main.resource_group_name

  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Individual custom table + DCR configurations are in separate files:
# - app_metrics.tf
# - security_events.tf
# - etc.
#
# Each file contains one module block calling ./modules/custom-log-table