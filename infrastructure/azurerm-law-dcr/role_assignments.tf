# Role Assignments for Custom Log Ingestion
# These assignments grant permissions needed to send data to custom tables via DCRs
#
# IMPORTANT: The Terraform service principal needs Owner or User Access Administrator role
# to create role assignments. This must be configured outside of Terraform (via Azure Portal/CLI).
#
# This file contains examples for assigning "Monitoring Metrics Publisher" role to identities
# that will ingest data into the custom tables. Uncomment and configure the appropriate example
# for your use case.

# Get current client configuration (useful for the examples below)
data "azurerm_client_config" "current" {}

# Example 1: Grant role to current user/service principal
# Useful for local testing of log ingestion, but typically not needed in production
#
# resource "azurerm_role_assignment" "current_user_metrics_publisher" {
#   principal_id         = data.azurerm_client_config.current.object_id
#   scope                = local.law_id
#   role_definition_name = "Monitoring Metrics Publisher"
#   description          = "Allow current user/SP to publish metrics to custom tables"
# }

# Example 2: Grant role to an Automation Account Managed Identity
# Uncomment and configure if you're using an Automation Account
#
# data "azurerm_automation_account" "main" {
#   name                = "your-automation-account-name"
#   resource_group_name = "your-automation-rg"
# }
#
# resource "azurerm_role_assignment" "automation_metrics_publisher" {
#   principal_id         = data.azurerm_automation_account.main.identity[0].principal_id
#   scope                = local.law_id
#   role_definition_name = "Monitoring Metrics Publisher"
#   description          = "Allow Automation Account to publish metrics to custom tables"
# }

# Example 3: Grant role to a User-Assigned Managed Identity
# Uncomment and configure if you're using a managed identity for data ingestion
#
# data "azurerm_user_assigned_identity" "ingestion" {
#   name                = "id-log-ingestion"
#   resource_group_name = var.law_resource_group_name
# }
#
# resource "azurerm_role_assignment" "managed_identity_metrics_publisher" {
#   principal_id         = data.azurerm_user_assigned_identity.ingestion.principal_id
#   scope                = local.law_id
#   role_definition_name = "Monitoring Metrics Publisher"
#   description          = "Allow managed identity to publish metrics to custom tables"
# }

# Example 4: Grant role to an Azure Function App or App Service
# Uncomment and configure if you're using App Service for data ingestion
#
# data "azurerm_linux_function_app" "ingestion" {
#   name                = "func-log-ingestion"
#   resource_group_name = "your-function-rg"
# }
#
# resource "azurerm_role_assignment" "function_metrics_publisher" {
#   principal_id         = data.azurerm_linux_function_app.ingestion.identity[0].principal_id
#   scope                = local.law_id
#   role_definition_name = "Monitoring Metrics Publisher"
#   description          = "Allow Function App to publish metrics to custom tables"
# }

# Note: The "Monitoring Metrics Publisher" role is required to send data to DCRs
# Scope can be at:
# - Log Analytics Workspace level (local.law_id)
# - Resource Group level (data.azurerm_resource_group.main.id)
# - Subscription level (more permissive, not recommended)
