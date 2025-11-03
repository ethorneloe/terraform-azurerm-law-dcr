# CI Testing for Custom Log Table Module

This directory contains end-to-end testing infrastructure for the `custom-log-table` module.

## Purpose

Automated testing that validates:
1. ✅ Module can create custom tables and DCRs
2. ✅ Data can be ingested via the DCR
3. ✅ Data appears correctly in Log Analytics
4. ✅ Resources are cleaned up after testing

## Test Workflow

The CI test is triggered by:
- Changes to `infrastructure/azurerm-law-dcr/modules/custom-log-table/`
- Changes to the `ci/` directory
- Manual workflow dispatch

### Test Steps

1. **Deploy Test Infrastructure**
   - Creates a temporary custom table named `CITest_CL`
   - Creates associated DCR
   - Uses dev environment configuration

2. **Ingest Test Data**
   - Generates unique test data with a GUID
   - Posts data to the DCR using the Logs Ingestion API
   - Uses the GitHub Actions service principal for authentication

3. **Verify Data**
   - Waits for data ingestion (1-5 minutes typical)
   - Queries the table for the test data
   - Validates the record was ingested correctly

4. **Cleanup**
   - Destroys all test resources
   - Runs even if previous steps fail

## Files

- **main.tf** - Test infrastructure (single custom table)
- **providers.tf** - Terraform providers configuration
- **variables.tf** - Input variables
- **outputs.tf** - Outputs for data ingestion
- **test-data-ingestion.ps1** - PowerShell script for ingestion testing
- **README.md** - This file

## Configuration

The test uses the dev environment configuration:
- Backend: `infrastructure/azurerm-law-dcr/env/dev/dev.tfbackend`
- Variables: `infrastructure/azurerm-law-dcr/env/dev/dev.tfvars`

## Running Locally

You can run the test locally:

```bash
cd ci

# Initialize
terraform init -backend-config=../infrastructure/azurerm-law-dcr/env/dev/dev.tfbackend

# Plan
terraform plan -var-file=../infrastructure/azurerm-law-dcr/env/dev/dev.tfvars

# Apply
terraform apply -var-file=../infrastructure/azurerm-law-dcr/env/dev/dev.tfvars

# Get outputs for testing
DCR_ID=$(terraform output -raw dcr_immutable_id)
STREAM=$(terraform output -raw stream_name)
DCE=$(terraform output -raw dce_logs_ingestion_endpoint)
TABLE=$(terraform output -raw table_name)
LAW=$(terraform output -raw law_name)
RG=$(terraform output -raw law_resource_group)

# Test data ingestion
pwsh test-data-ingestion.ps1 \
  -DcrImmutableId "$DCR_ID" \
  -StreamName "$STREAM" \
  -DceEndpoint "$DCE" \
  -TableName "$TABLE" \
  -WorkspaceName "$LAW" \
  -ResourceGroup "$RG"

# Cleanup
terraform destroy -var-file=../infrastructure/azurerm-law-dcr/env/dev/dev.tfvars
```

## GitHub Actions Workflow

See `.github/workflows/ci-module-test.yml` for the automated workflow.

## Test Data Schema

The test table uses this schema:
- `TimeGenerated` (datetime) - Timestamp
- `TestID` (string) - Unique GUID for each test run
- `TestResult` (string) - Test result status
- `Duration` (real) - Test duration in seconds
- `Message` (string) - Test message

## Prerequisites

For the CI workflow to run, ensure:
- GitHub Environment `dev` exists with required secrets
- Service principal has:
  - Contributor on the LAW resource group
  - Monitoring Metrics Publisher on the LAW (for data ingestion)
- Dev environment LAW and DCE exist
