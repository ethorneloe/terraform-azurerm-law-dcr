# Environment
environment = "test"

# Existing Log Analytics Workspace
law_name                = "law-test-001"
law_resource_group_name = "rg-monitoring-test"

# Existing Data Collection Endpoint (optional - set to null if doesn't exist)
dce_name                = "dce-test-shared"
dce_resource_group_name = "rg-monitoring-test"

# Common tags applied to all custom tables
tags = {
  CostCenter = "IT"
  Owner      = "DevOps"
  Project    = "CustomLogging"
}