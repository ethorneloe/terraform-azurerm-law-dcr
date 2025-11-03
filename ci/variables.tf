# CI Test Variables
variable "law_name" {
  description = "Name of the existing Log Analytics Workspace"
  type        = string
}

variable "law_resource_group_name" {
  description = "Resource group name where the Log Analytics Workspace exists"
  type        = string
}

variable "dce_name" {
  description = "Name of the existing Data Collection Endpoint (optional)"
  type        = string
  default     = null
}

variable "dce_resource_group_name" {
  description = "Resource group name where the Data Collection Endpoint exists (optional)"
  type        = string
  default     = null
}
