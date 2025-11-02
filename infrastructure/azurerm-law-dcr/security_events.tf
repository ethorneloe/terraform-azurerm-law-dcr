# Security Events Custom Table + DCR
# This table collects security-related events and alerts

module "security_events" {
  source = "./modules/custom-log-table"

  table_name = "SecurityEvents_CL"

  schema = {
    name = "SecurityEvents_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime", description = "The time at which the event was generated" },
      { name = "EventType", type = "string", description = "Type of security event" },
      { name = "Severity", type = "int", description = "Severity level (1-4)" },
      { name = "SourceIP", type = "string", description = "Source IP address" },
      { name = "TargetIP", type = "string", description = "Target IP address" },
      { name = "UserName", type = "string", description = "User name" },
      { name = "Action", type = "string", description = "Action taken" },
      { name = "Result", type = "string", description = "Result of the action" },
      { name = "Description", type = "string", description = "Event description" }
    ]
  }

  log_analytics_workspace_id  = local.law_id
  data_collection_endpoint_id = local.dce_id
  resource_group_name         = local.rg_name
  location                    = local.location

  retention_in_days       = 90          # Longer retention for security events
  total_retention_in_days = 365         # 1 year total with archive
  table_plan              = "Analytics" # Analytics for better querying

  # Example KQL transformation to enrich data
  transform_kql = <<-KQL
    source
    | extend SeverityLevel = case(
        Severity == 1, "Critical",
        Severity == 2, "High",
        Severity == 3, "Medium",
        Severity == 4, "Low",
        "Unknown"
      )
  KQL

  tags = merge(local.common_tags, {
    Purpose    = "Security Monitoring"
    TableType  = "Security"
    Compliance = "Required"
  })
}
