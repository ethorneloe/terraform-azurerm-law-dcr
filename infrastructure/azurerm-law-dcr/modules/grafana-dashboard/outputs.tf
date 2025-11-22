output "dashboard_id" {
  description = "ID of the Grafana dashboard"
  value       = grafana_dashboard.main.id
}

output "dashboard_uid" {
  description = "UID of the Grafana dashboard"
  value       = grafana_dashboard.main.uid
}

output "dashboard_url" {
  description = "URL of the Grafana dashboard"
  value       = grafana_dashboard.main.url
}

output "dashboard_name" {
  description = "Name of the Grafana dashboard"
  value       = var.dashboard_name
}
