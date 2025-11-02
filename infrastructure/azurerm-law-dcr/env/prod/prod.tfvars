# Environment
environment = "prod"

# Existing Log Analytics Workspace
law_name                = "law-prod-001"
law_resource_group_name = "rg-monitoring"

# Existing Data Collection Endpoint (optional - set to null if doesn't exist)
dce_name                = "dce-prod-shared"
dce_resource_group_name = "rg-monitoring"

# Common tags applied to all custom tables
tags = {
  CostCenter = "Operations"
  Owner      = "Platform Team"
  Project    = "CustomLogging"
}
