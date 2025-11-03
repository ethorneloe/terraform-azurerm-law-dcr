# CI Test - Single Custom Table for Module Testing

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

# Local values
locals {
  law_id   = data.azurerm_log_analytics_workspace.main.id
  dce_id   = var.dce_name != null ? data.azurerm_monitor_data_collection_endpoint.main[0].id : null
  location = data.azurerm_log_analytics_workspace.main.location
  rg_name  = data.azurerm_log_analytics_workspace.main.resource_group_name
}

# Get the current client (GitHub Actions service principal)
data "azurerm_client_config" "current" {}

# Test Custom Table - CI Test Data
module "ci_test_table" {
  source = "../infrastructure/azurerm-law-dcr/modules/custom-log-table"

  table_name = "CITest_CL"

  schema = {
    name = "CITest_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime", description = "The time at which the data was generated" },
      { name = "TestID", type = "string", description = "Unique test identifier" },
      { name = "TestResult", type = "string", description = "Test result status" },
      { name = "Duration", type = "real", description = "Test duration in seconds" },
      { name = "Message", type = "string", description = "Test message" }
    ]
  }

  log_analytics_workspace_id  = local.law_id
  data_collection_endpoint_id = local.dce_id
  resource_group_name         = local.rg_name
  location                    = local.location

  # Use Basic plan for CI testing (cheaper and faster)
  table_plan = "Basic"

  transform_kql = "source"

  tags = {
    Purpose     = "CI Testing"
    Environment = "CI"
    Managed     = "GitHub Actions"
  }
}

# Note: RBAC permissions are managed manually outside of this CI test
# The GitHub Actions service principal should have "Monitoring Metrics Publisher"
# role at the resource group level to allow data ingestion to all DCRs
