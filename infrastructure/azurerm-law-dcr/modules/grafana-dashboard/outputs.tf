output "dashboard_id" {
  description = "Resource ID of the Grafana dashboard"
  value       = azapi_resource.grafana_dashboard.id
}

output "dashboard_name" {
  description = "Name of the Grafana dashboard"
  value       = var.dashboard_name
}
