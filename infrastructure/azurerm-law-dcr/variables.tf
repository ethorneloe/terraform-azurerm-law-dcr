# Environment configuration
variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

# Existing Log Analytics Workspace
variable "law_name" {
  description = "Name of the existing Log Analytics Workspace"
  type        = string
}

variable "law_resource_group_name" {
  description = "Resource group name where the Log Analytics Workspace exists"
  type        = string
}

# Existing Data Collection Endpoint (optional)
variable "dce_name" {
  description = "Name of the existing Data Collection Endpoint (optional - only if it exists)"
  type        = string
  default     = null
}

variable "dce_resource_group_name" {
  description = "Resource group name where the Data Collection Endpoint exists (optional)"
  type        = string
  default     = null
}

# Common tags applied to all resources
variable "tags" {
  description = "Common tags to apply to all resources (merged with table-specific tags)"
  type        = map(string)
  default     = {}
}

# RBAC for log ingestion
variable "log_ingestion_sp_object_ids" {
  description = "List of service principal Object IDs that need log ingestion access. Get Object IDs with: az ad sp show --id <app-id> --query id -o tsv"
  type        = list(string)
  default     = []
}

# Azure Managed Grafana configuration (optional)
variable "grafana_name" {
  description = "Name of the existing Azure Managed Grafana workspace (optional - set to null to skip Grafana dashboards)"
  type        = string
  default     = null
}

variable "grafana_resource_group_name" {
  description = "Resource group name where the Azure Managed Grafana workspace exists (optional)"
  type        = string
  default     = null
}

variable "deploy_grafana_dashboards" {
  description = "Whether to deploy Grafana dashboards (requires grafana_name to be set)"
  type        = bool
  default     = true
}
