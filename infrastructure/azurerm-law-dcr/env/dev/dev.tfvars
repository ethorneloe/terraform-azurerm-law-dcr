# Environment
environment = "dev"

# Existing Log Analytics Workspace
law_name                = "law-dev-001"
law_resource_group_name = "rg-monitoring-dev"

# Existing Data Collection Endpoint (optional - set to null if doesn't exist)
dce_name                = "dce-dev-shared"
dce_resource_group_name = "rg-monitoring-dev"

# Common tags applied to all custom tables
tags = {
  CostCenter = "IT"
  Owner      = "DevOps"
  Project    = "CustomLogging"
}