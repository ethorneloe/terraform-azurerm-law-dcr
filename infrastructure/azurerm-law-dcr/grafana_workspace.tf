# Azure Managed Grafana Workspace (Optional)
# Uncomment this section if you want Terraform to create the Grafana workspace
# Otherwise, use an existing Grafana workspace by providing its resource ID in variables

# resource "azurerm_dashboard_grafana" "main" {
#   name                              = "grafana-${var.environment}"
#   resource_group_name               = local.rg_name
#   location                          = local.location
#   api_key_enabled                   = true
#   deterministic_outbound_ip_enabled = false
#   public_network_access_enabled     = true
#   sku                               = "Standard"
#
#   identity {
#     type = "SystemAssigned"
#   }
#
#   azure_monitor_workspace_integrations {
#     resource_id = local.law_id
#   }
#
#   tags = merge(local.common_tags, {
#     Purpose = "Grafana Dashboards for Custom Log Tables"
#   })
# }
#
# # Grant Grafana managed identity access to read from Log Analytics
# resource "azurerm_role_assignment" "grafana_monitoring_reader" {
#   principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
#   scope                = local.law_id
#   role_definition_name = "Monitoring Reader"
#   description          = "Allow Grafana to read from Log Analytics Workspace"
# }

# Data source to reference existing Grafana workspace
data "azurerm_dashboard_grafana" "main" {
  count               = var.grafana_name != null ? 1 : 0
  name                = var.grafana_name
  resource_group_name = var.grafana_resource_group_name
}

locals {
  grafana_id = var.grafana_name != null ? data.azurerm_dashboard_grafana.main[0].id : null
}
