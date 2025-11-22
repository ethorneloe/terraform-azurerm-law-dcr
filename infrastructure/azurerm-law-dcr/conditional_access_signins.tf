# Entra ID Conditional Access Sign-ins Custom Table + DCR
# This table collects sign-in events with conditional access policy evaluation details

module "conditional_access_signins" {
  source = "./modules/custom-log-table"

  table_name = "ConditionalAccessSignIns_CL"

  schema = {
    name = "ConditionalAccessSignIns_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime", description = "The time at which the sign-in event occurred" },
      { name = "UserPrincipalName", type = "string", description = "User principal name" },
      { name = "UserId", type = "string", description = "User object ID" },
      { name = "AppDisplayName", type = "string", description = "Application display name" },
      { name = "AppId", type = "string", description = "Application ID" },
      { name = "IPAddress", type = "string", description = "IP address of the client" },
      { name = "Location", type = "string", description = "Sign-in location (city, country)" },
      { name = "DeviceOS", type = "string", description = "Device operating system" },
      { name = "DeviceBrowser", type = "string", description = "Browser used for sign-in" },
      { name = "IsCompliant", type = "boolean", description = "Device compliance status" },
      { name = "IsManaged", type = "boolean", description = "Device management status" },
      { name = "AuthenticationMethod", type = "string", description = "Authentication method used" },
      { name = "MfaDetail", type = "string", description = "MFA details" },
      { name = "ConditionalAccessStatus", type = "string", description = "Overall CA status (success, failure, notApplied)" },
      { name = "PolicyName", type = "string", description = "Conditional access policy name" },
      { name = "PolicyResult", type = "string", description = "Policy result (success, failure, notApplied)" },
      { name = "PolicyId", type = "string", description = "Policy ID" },
      { name = "RiskLevel", type = "string", description = "Sign-in risk level" },
      { name = "RiskState", type = "string", description = "Risk state" },
      { name = "Status", type = "string", description = "Sign-in status (success, failure, interrupted)" },
      { name = "FailureReason", type = "string", description = "Failure reason if applicable" },
      { name = "CorrelationId", type = "string", description = "Correlation ID for tracking" }
    ]
  }

  log_analytics_workspace_id  = local.law_id
  data_collection_endpoint_id = local.dce_id
  resource_group_name         = local.rg_name
  location                    = local.location

  retention_in_days       = 90          # 90 days hot retention for security data
  total_retention_in_days = 730         # 2 years total for compliance
  table_plan              = "Analytics" # Analytics plan for better querying

  # KQL transformation to add risk categorization
  transform_kql = <<-KQL
    source
    | extend RiskCategory = case(
        RiskLevel == "high" or RiskLevel == "critical", "High Risk",
        RiskLevel == "medium", "Medium Risk",
        RiskLevel == "low", "Low Risk",
        RiskLevel == "none" or RiskLevel == "", "No Risk",
        "Unknown"
      )
    | extend StatusCategory = case(
        Status == "success", "Success",
        Status == "failure", "Failed",
        Status == "interrupted", "Interrupted",
        "Unknown"
      )
  KQL

  tags = merge(local.common_tags, {
    Purpose    = "Conditional Access Monitoring"
    TableType  = "Security"
    DataSource = "Entra ID Sign-ins"
    Compliance = "Required"
  })
}
