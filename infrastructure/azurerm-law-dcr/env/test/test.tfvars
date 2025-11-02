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

# Service Principals for Log Ingestion (RBAC)
# Add Object IDs of service principals that need to push data to custom tables
# Get Object ID: az ad sp show --id <app-id> --query id -o tsv
log_ingestion_sp_object_ids = []