variable "table_name" {
  description = "Name of the custom table (must end with _CL)"
  type        = string

  validation {
    condition     = can(regex("_CL$", var.table_name))
    error_message = "Table name must end with _CL"
  }
}

variable "schema" {
  description = "Table schema definition with columns"
  type = object({
    name = string
    columns = list(object({
      name        = string
      type        = string
      description = optional(string, "")
    }))
  })
}

variable "log_analytics_workspace_id" {
  description = "LAW resource ID"
  type        = string
}

variable "data_collection_endpoint_id" {
  description = "DCE resource ID (optional)"
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Resource group for DCR"
  type        = string
}

variable "location" {
  description = "Azure region for DCR"
  type        = string
}

variable "retention_in_days" {
  description = "Retention in days (not supported for Basic plan - omit or set to null)"
  type        = number
  default     = null
}

variable "total_retention_in_days" {
  description = "Total retention in days including archive (not supported for Basic plan - omit or set to null)"
  type        = number
  default     = null
}

variable "table_plan" {
  description = "Analytics or Basic"
  type        = string
  default     = "Analytics"

  validation {
    condition     = contains(["Analytics", "Basic"], var.table_plan)
    error_message = "Must be Analytics or Basic"
  }
}

variable "transform_kql" {
  description = "KQL transformation (defaults to 'source' for no transform)"
  type        = string
  default     = "source"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}