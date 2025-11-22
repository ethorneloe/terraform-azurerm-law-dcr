# Deploy Grafana dashboard from JSON file
resource "azapi_resource" "grafana_dashboard" {
  type      = "Microsoft.Dashboard/grafana/dashboards@2023-09-01"
  name      = var.dashboard_name
  parent_id = var.grafana_id

  body = {
    properties = {
      dashboard = var.dashboard_json
    }
  }

  tags = var.tags
}
