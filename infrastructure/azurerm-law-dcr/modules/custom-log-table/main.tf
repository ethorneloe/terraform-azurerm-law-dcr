locals {
  # Build table properties, only including retention if specified
  table_properties = merge(
    {
      schema = {
        name    = var.schema.name
        columns = var.schema.columns
      }
      plan = var.table_plan
    },
    var.retention_in_days != null ? { retentionInDays = var.retention_in_days } : {},
    var.total_retention_in_days != null ? { totalRetentionInDays = var.total_retention_in_days } : {}
  )
}

# Change to test CI
# Create the custom table in Log Analytics Workspace using AzAPI
resource "azapi_resource" "custom_table" {
  name      = var.table_name
  parent_id = var.log_analytics_workspace_id
  type      = "Microsoft.OperationalInsights/workspaces/tables@2022-10-01"

  body = {
    properties = local.table_properties
  }
}

# Create the Data Collection Rule (DCR)
resource "azurerm_monitor_data_collection_rule" "main" {
  name                = "dcr-${replace(lower(var.table_name), "_", "-")}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Link to Data Collection Endpoint if provided
  data_collection_endpoint_id = var.data_collection_endpoint_id

  # Define the stream declaration (input schema)
  stream_declaration {
    stream_name = "Custom-${var.table_name}"

    dynamic "column" {
      for_each = var.schema.columns
      content {
        name = column.value.name
        type = column.value.type
      }
    }
  }

  # Define destinations (where data goes)
  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = "destination-log-analytics"
    }
  }

  # Define data flows (how data is routed and transformed)
  data_flow {
    streams       = ["Custom-${var.table_name}"]
    destinations  = ["destination-log-analytics"]
    transform_kql = var.transform_kql
    output_stream = "Custom-${var.table_name}"
  }

  tags = var.tags

  depends_on = [
    azapi_resource.custom_table
  ]
}
