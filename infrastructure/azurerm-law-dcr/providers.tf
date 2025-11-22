terraform {
  required_version = "~> 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.0"
    }
  }
  backend "azurerm" {
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

provider "azapi" {
}

# Grafana provider for deploying dashboards to Azure Managed Grafana
# This uses Azure AD authentication to connect to Grafana
# The provider is only configured if a Grafana endpoint is available
provider "grafana" {
  # URL is dynamically set from the Grafana workspace endpoint
  url = local.grafana_endpoint

  # Use Azure AD authentication (same credentials as azurerm provider)
  auth = local.grafana_endpoint != null ? "azure" : null
}