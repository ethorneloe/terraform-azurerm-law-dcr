variable "dashboard_name" {
  description = "Name of the Grafana dashboard (used for reference only)"
  type        = string
}

variable "dashboard_json" {
  description = "Grafana dashboard JSON definition"
  type        = string
}

variable "tags" {
  description = "Tags to apply (Note: Grafana dashboards don't support Azure tags directly)"
  type        = map(string)
  default     = {}
}

# Note: grafana_id is no longer needed with Grafana provider
# The provider configuration handles the Grafana instance connection
