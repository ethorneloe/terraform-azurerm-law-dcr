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

# Service Principals for Log Ingestion (RBAC)
# Add Object IDs of service principals that need to push data to custom tables
# Get Object ID: az ad sp show --id <app-id> --query id -o tsv
#
# Example with one SP (most common):
# log_ingestion_sp_object_ids = ["12345678-1234-1234-1234-123456789012"]
#
# Example with multiple SPs (for different apps):
# log_ingestion_sp_object_ids = [
#   "12345678-1234-1234-1234-123456789012",  # SP for App1
#   "87654321-4321-4321-4321-210987654321"   # SP for App2
# ]
log_ingestion_sp_object_ids = []

# Azure Managed Grafana Configuration
# Set create_grafana_instance = true to create a new Grafana instance
# Or set it to false and provide existing Grafana details to use an existing instance
#
# Option 1: Create new Grafana instance
# create_grafana_instance        = true
# grafana_name                   = "grafana-dev-001"
# grafana_resource_group_name    = "rg-monitoring-dev"  # Optional - defaults to LAW resource group
# deploy_grafana_dashboards      = true
#
# Option 2: Use existing Grafana instance
# create_grafana_instance        = false
# grafana_name                   = "existing-grafana-001"
# grafana_resource_group_name    = "rg-monitoring-dev"
# deploy_grafana_dashboards      = true