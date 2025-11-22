# Deploy Grafana dashboard using the Grafana provider
# Note: This requires the Grafana provider to be configured with access to your Azure Managed Grafana instance

resource "grafana_dashboard" "main" {
  config_json = var.dashboard_json

  lifecycle {
    ignore_changes = [
      # Ignore changes made through Grafana UI
      config_json
    ]
  }
}
