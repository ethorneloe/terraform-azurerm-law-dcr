# Azure Managed Grafana Workspace
#
# IMPORTANT: To deploy Grafana dashboards via Terraform, you need an Azure Managed Grafana instance.
# You have two options:
#
# Option 1: Create a new Azure Managed Grafana instance (recommended for new deployments)
#   - Uncomment the resource block below
#   - Set create_grafana_instance = true in your tfvars
#
# Option 2: Use an existing Azure Managed Grafana instance
#   - Keep the resource block commented out
#   - Provide grafana_name and grafana_resource_group_name in your tfvars
#   - Set create_grafana_instance = false

# Option 1: Create new Azure Managed Grafana instance
resource "azurerm_dashboard_grafana" "main" {
  count                             = var.create_grafana_instance ? 1 : 0
  name                              = var.grafana_name != null ? var.grafana_name : "grafana-${var.environment}"
  resource_group_name               = var.grafana_resource_group_name != null ? var.grafana_resource_group_name : data.azurerm_log_analytics_workspace.main.resource_group_name
  location                          = data.azurerm_log_analytics_workspace.main.location
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = false
  public_network_access_enabled     = true
  sku                               = "Standard"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = data.azurerm_log_analytics_workspace.main.id
  }

  tags = merge(local.common_tags, {
    Purpose = "Grafana Dashboards for Custom Log Tables"
  })
}

# Grant Grafana managed identity access to read from Log Analytics
resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  count                = var.create_grafana_instance ? 1 : 0
  principal_id         = azurerm_dashboard_grafana.main[0].identity[0].principal_id
  scope                = data.azurerm_log_analytics_workspace.main.id
  role_definition_name = "Monitoring Reader"
  description          = "Allow Grafana to read from Log Analytics Workspace"
}

# Option 2: Reference existing Azure Managed Grafana instance
data "azurerm_dashboard_grafana" "existing" {
  count               = !var.create_grafana_instance && var.grafana_name != null ? 1 : 0
  name                = var.grafana_name
  resource_group_name = var.grafana_resource_group_name
}

# Local value to get the Grafana endpoint (from either created or existing instance)
locals {
  grafana_endpoint = (
    var.create_grafana_instance && length(azurerm_dashboard_grafana.main) > 0 ?
    azurerm_dashboard_grafana.main[0].endpoint :
    !var.create_grafana_instance && var.grafana_name != null && length(data.azurerm_dashboard_grafana.existing) > 0 ?
    data.azurerm_dashboard_grafana.existing[0].endpoint :
    null
  )

  grafana_id = (
    var.create_grafana_instance && length(azurerm_dashboard_grafana.main) > 0 ?
    azurerm_dashboard_grafana.main[0].id :
    !var.create_grafana_instance && var.grafana_name != null && length(data.azurerm_dashboard_grafana.existing) > 0 ?
    data.azurerm_dashboard_grafana.existing[0].id :
    null
  )

  deploy_dashboards = local.grafana_endpoint != null && var.deploy_grafana_dashboards
}
