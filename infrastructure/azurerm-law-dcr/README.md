# Azure Log Analytics Custom Table & DCR Deployment

This Terraform configuration deploys custom tables and Data Collection Rules (DCR) to existing Log Analytics Workspaces and Data Collection Endpoints.

## Structure

```
infrastructure/azurerm-law-dcr/
├── main.tf                # Shared data sources and locals
├── variables.tf           # Environment-level variables (LAW, DCE, tags)
├── outputs.tf             # Outputs for all tables
├── providers.tf           # Provider configuration
├── app_metrics.tf         # Custom table: AppMetrics_CL + DCR
├── security_events.tf     # Custom table: SecurityEvents_CL + DCR
├── [your_table].tf        # Add more custom table files here
├── env/                   # Environment-specific configurations
│   ├── dev/
│   │   └── dev.tfvars
│   ├── test/
│   │   └── test.tfvars
│   └── prod/
│       └── prod.tfvars
└── modules/
    └── custom-log-table/  # Reusable module
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Key Design Principles

1. **One file per custom table**: Each `.tf` file (except main.tf) represents one custom table + DCR combination
2. **Shared infrastructure**: `main.tf` contains data sources for LAW/DCE and reusable locals
3. **Non-monolithic**: Easy to add/remove tables by adding/removing individual files
4. **Environment variables**: Only environment-level config (LAW, DCE, common tags) in `.tfvars`
5. **Table-specific config**: Schema, retention, and KQL transforms are defined directly in each table's `.tf` file

## Prerequisites

- Existing Log Analytics Workspace (LAW)
- Existing Data Collection Endpoint (DCE) - optional
- Azure subscription with appropriate permissions
- Terraform >= 1.9
- Azure CLI or Azure DevOps pipeline with OIDC authentication

## Usage

### Local Development

1. **Initialize Terraform:**
   ```bash
   cd infrastructure/azurerm-law-dcr
   terraform init
   ```

2. **Plan deployment for specific environment:**
   ```bash
   terraform plan -var-file="env/dev/dev.tfvars"
   ```

3. **Apply deployment:**
   ```bash
   terraform apply -var-file="env/dev/dev.tfvars"
   ```

### Pipeline Usage (Recommended)

Your pipeline should:
1. Authenticate using OIDC (handles tenant/subscription automatically)
2. Select the appropriate `.tfvars` file based on environment
3. Run terraform init/plan/apply

Example Azure DevOps snippet:
```yaml
- task: TerraformTaskV4@4
  inputs:
    command: 'apply'
    workingDirectory: '$(System.DefaultWorkingDirectory)/infrastructure/azurerm-law-dcr'
    commandOptions: '-var-file="env/$(environment)/$(environment).tfvars"'
```

## Adding a New Custom Table

To add a new custom table, simply create a new `.tf` file:

```hcl
# my_new_table.tf
module "my_new_table" {
  source = "./modules/custom-log-table"

  table_name = "MyNewTable_CL"

  schema = {
    name = "MyNewTable_CL"
    columns = [
      { name = "TimeGenerated", type = "datetime", description = "Timestamp of the event" },
      { name = "CustomField1",  type = "string",   description = "Description of field 1" },
      { name = "CustomField2",  type = "int",      description = "Description of field 2" }
    ]
  }

  log_analytics_workspace_id  = local.law_id
  data_collection_endpoint_id = local.dce_id
  resource_group_name         = local.rg_name
  location                    = local.location

  retention_in_days       = 30
  total_retention_in_days = 90
  table_plan              = "Analytics"
  transform_kql           = "source"

  tags = merge(local.common_tags, {
    Purpose = "My Custom Purpose"
  })
}
```

Then add outputs in `outputs.tf`:
```hcl
output "my_new_table_dcr_id" {
  description = "DCR Resource ID for My New Table"
  value       = module.my_new_table.dcr_id
}

output "my_new_table_dcr_immutable_id" {
  description = "DCR Immutable ID (use for data ingestion)"
  value       = module.my_new_table.dcr_immutable_id
}
```

## Configuration

### Environment-Specific Variables (in .tfvars files)

Update the `.tfvars` files in each environment folder:

- **environment**: Environment name (dev, test, prod)
- **law_name**: Name of existing Log Analytics Workspace
- **law_resource_group_name**: Resource group where LAW exists
- **dce_name**: Name of existing DCE (set to `null` if doesn't exist)
- **dce_resource_group_name**: Resource group where DCE exists
- **tags**: Common tags applied to all resources (merged with table-specific tags)

Example:
```hcl
# env/dev/dev.tfvars
environment = "dev"

law_name                = "law-dev-001"
law_resource_group_name = "rg-monitoring-dev"

dce_name                = "dce-dev-shared"
dce_resource_group_name = "rg-monitoring-dev"

tags = {
  CostCenter = "IT"
  Owner      = "DevOps"
}
```

### Table-Specific Configuration (in individual .tf files)

Each custom table file defines:

- **table_name**: Must end with `_CL`
- **schema**: Array of column definitions
- **retention_in_days**: Hot data retention
- **total_retention_in_days**: Total retention including archive
- **table_plan**: "Analytics" (better querying) or "Basic" (cheaper, high volume)
- **transform_kql**: KQL transformation (use `"source"` for no transformation)
- **tags**: Additional table-specific tags (merged with common tags)

### Example Schema

```hcl
schema = {
  name = "MyTable_CL"
  columns = [
    { name = "TimeGenerated", type = "datetime", description = "Event timestamp" },
    { name = "Message",       type = "string",   description = "Log message" },
    { name = "Level",         type = "int",      description = "Log level" },
    { name = "MetricValue",   type = "real",     description = "Metric value" },
    { name = "IsActive",      type = "boolean",  description = "Active status" }
  ]
}
```

**Supported types**: `datetime`, `string`, `int`, `long`, `real`, `boolean`, `dynamic`

**Note**: The schema name must match the table_name parameter.

## Provider Configuration

The `providers.tf` file is configured for backend state storage in Azure Storage. Configure your backend in the pipeline or locally:

```bash
terraform init \
  -backend-config="resource_group_name=rg-terraform-state" \
  -backend-config="storage_account_name=sttfstate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=law-dcr-${ENVIRONMENT}.tfstate"
```

## Role Assignments & Permissions

To send data to custom tables via Data Collection Rules, the sending identity needs the **Monitoring Metrics Publisher** role.

The [role_assignments.tf](role_assignments.tf) file contains examples for:
- Current user/service principal (for local testing)
- Automation Account managed identity
- User-assigned managed identity
- Azure Function App / App Service identity

### Configuring for Your Identity

1. **For Automation Accounts**: Uncomment the automation account section in `role_assignments.tf` and update the account name
2. **For Managed Identities**: Uncomment the managed identity section and update the identity name
3. **For Function Apps**: Uncomment the function app section and update the app name

Example for an Automation Account:

```hcl
data "azurerm_automation_account" "main" {
  name                = "aa-${var.environment}-01"
  resource_group_name = "rg-automation-${var.environment}"
}

resource "azurerm_role_assignment" "automation_metrics_publisher" {
  principal_id         = data.azurerm_automation_account.main.identity[0].principal_id
  scope                = local.law_id
  role_definition_name = "Monitoring Metrics Publisher"
  description          = "Allow Automation Account to publish metrics to custom tables"
}
```

## Important Notes

1. **Provider Configuration**: Requires both `azurerm` and `azapi` providers
2. **Authentication**: Handled by pipeline OIDC or Azure CLI login
3. **DCE is Optional**: Set `dce_name = null` if you don't have an existing DCE
4. **Table Naming**: Custom tables must end with `_CL` suffix
5. **Module Reusability**: The module is called multiple times, once per table
6. **Shared Locals**: All table files reference `local.law_id`, `local.dce_id`, `local.rg_name`, etc.
7. **Schema Format**: Schema must include table name and column descriptions
8. **RBAC Required**: Sending identities need "Monitoring Metrics Publisher" role

## Example Tables

### AppMetrics_CL ([app_metrics.tf](app_metrics.tf))
- High-volume application performance metrics
- Uses "Basic" plan for cost efficiency
- Simple schema with metric name/value pairs

### SecurityEvents_CL ([security_events.tf](security_events.tf))
- Security events and alerts
- Uses "Analytics" plan for better querying
- Longer retention (90 days hot, 1 year total)
- Includes KQL transformation to enrich severity levels

## Outputs

After successful deployment, outputs are available per table:

**Shared outputs:**
- `law_id`: Log Analytics Workspace resource ID
- `dce_id`: Data Collection Endpoint resource ID
- `location`: Azure region

**Per-table outputs:**
- `{table}_dcr_id`: Resource ID of the DCR
- `{table}_dcr_immutable_id`: Immutable ID for data ingestion (use this in your apps)
- `{table}_stream_name`: Stream name for API ingestion

## Support

For issues or questions, refer to:
- [Terraform AzureRM Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Monitor Custom Logs Documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview)
