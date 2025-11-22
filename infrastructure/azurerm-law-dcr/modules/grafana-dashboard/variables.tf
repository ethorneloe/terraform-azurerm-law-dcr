variable "dashboard_name" {
  description = "Name of the Grafana dashboard"
  type        = string
}

variable "grafana_id" {
  description = "Resource ID of the Azure Managed Grafana instance"
  type        = string
}

variable "dashboard_json" {
  description = "Grafana dashboard JSON definition"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the dashboard"
  type        = map(string)
  default     = {}
}
