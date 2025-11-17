# Conditional Access Monitoring Workbook

resource "random_uuid" "workbook" {}

resource "azurerm_application_insights_workbook" "conditional_access" {
  name                = random_uuid.workbook.result
  resource_group_name = local.rg_name
  location            = local.location
  display_name        = "Conditional Access Monitoring"
  source_id           = lower(local.law_id)
  category            = "workbook"

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "## Conditional Access Policy Monitoring\n\nComprehensive overview of Conditional Access policies, named locations, and exemptions."
        }
        name = "text - header"
      },
      {
        type = 9
        content = {
          version = "KqlParameterItem/1.0"
          parameters = [
            {
              id           = "timerange-param"
              version      = "KqlParameterItem/1.0"
              name         = "TimeRange"
              label        = "Time Range"
              type         = 4
              isRequired   = true
              value        = { durationMs = 604800000 }
              typeSettings = {
                selectableValues = [
                  { durationMs = 86400000 },
                  { durationMs = 604800000 },
                  { durationMs = 2592000000 },
                  { durationMs = 7776000000 }
                ]
                allowCustom = true
              }
            }
          ]
          style        = "pills"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
        }
        name = "parameters - time range"
      },
      {
        type = 1
        content = {
          json = "### Policy Overview"
        }
        name = "text - policy overview"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| summarize Count=count() by State\n| render piechart"
          size          = 0
          title         = "Policies by State"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "piechart"
        }
        customWidth = "50"
        name        = "query - policies by state"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| where State == 'enabled'\n| summarize Count=count() by tostring(BuiltInControls)\n| top 10 by Count desc"
          size          = 0
          title         = "Top Grant Controls Required"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "barchart"
        }
        customWidth = "50"
        name        = "query - top grant controls"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| project TimeGenerated, DisplayName, State, Modified\n| order by Modified desc\n| take 20"
          size          = 0
          title         = "Recently Modified Policies"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "table"
        }
        name = "query - recently modified"
      },
      {
        type = 1
        content = {
          json = "### Named Locations"
        }
        name = "text - named locations"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessNamedLocations_CL\n| where TimeGenerated {TimeRange}\n| summarize Count=count() by IsTrusted\n| extend TrustStatus = iff(IsTrusted == true, 'Trusted', 'Untrusted')\n| project TrustStatus, Count"
          size          = 0
          title         = "Named Locations by Trust Status"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "piechart"
        }
        customWidth = "50"
        name        = "query - locations by trust"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessNamedLocations_CL\n| where TimeGenerated {TimeRange}\n| where isnotempty(Countries)\n| mv-expand Country = Countries\n| extend CountryCode = tostring(Country.Code)\n| where isnotempty(CountryCode)\n| summarize Count=count() by CountryCode\n| top 10 by Count desc"
          size          = 0
          title         = "Top 10 Countries in Named Locations"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "barchart"
        }
        customWidth = "50"
        name        = "query - top countries"
      },
      {
        type = 1
        content = {
          json = "### Advanced Policy Features"
        }
        name = "text - advanced features"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| where State == 'enabled'\n| where isnotempty(UserRiskLevels) or isnotempty(SignInRiskLevels)\n| project DisplayName, UserRiskLevels, SignInRiskLevels\n| take 20"
          size          = 0
          title         = "Risk-Based Policies"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "table"
        }
        customWidth = "50"
        name        = "query - risk policies"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| where State == 'enabled'\n| summarize PoliciesWithAuthStrength = countif(isnotempty(AuthenticationStrengthId)),\n            TotalPolicies = count()\n| extend PercentageWithAuthStrength = round((PoliciesWithAuthStrength * 100.0) / TotalPolicies, 2)\n| project Metric = 'Auth Strength Adoption', Percentage = PercentageWithAuthStrength, PoliciesWithAuthStrength, TotalPolicies"
          size          = 0
          title         = "Authentication Strength Adoption"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "table"
        }
        customWidth = "50"
        name        = "query - auth strength"
      },
      {
        type = 1
        content = {
          json = "### Trends & Usage"
        }
        name = "text - trends"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessPolicies_CL\n| where TimeGenerated > ago(30d)\n| summarize arg_max(TimeGenerated, *) by PolicyId\n| summarize PolicyCount=count() by bin(TimeGenerated, 1d)"
          size          = 0
          title         = "Policy Count Over Time (30 days)"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "timechart"
        }
        name = "query - policy count trend"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| where State == 'enabled'\n| where isnotempty(IncludeLocations)\n| mv-expand Location = IncludeLocations\n| extend LocationName = tostring(Location.DisplayName)\n| where isnotempty(LocationName)\n| summarize PolicyCount=count() by LocationName\n| top 10 by PolicyCount desc"
          size          = 0
          title         = "Top Named Locations Referenced in Policies"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "barchart"
        }
        customWidth = "50"
        name        = "query - top locations used"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| where State == 'enabled'\n| where isnotempty(IncludePlatforms)\n| mv-expand Platform = IncludePlatforms\n| summarize PolicyCount=count() by tostring(Platform)"
          size          = 0
          title         = "Policies by Device Platform"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "barchart"
        }
        customWidth = "50"
        name        = "query - platforms"
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = "ConditionalAccessNamedLocations_CL\n| where TimeGenerated {TimeRange}\n| extend IPCount = array_length(IpRanges),\n         CountryCount = array_length(Countries)\n| project DisplayName, IsTrusted, IPCount, CountryCount, ModifiedDateTime\n| order by ModifiedDateTime desc\n| take 20"
          size          = 0
          title         = "Named Locations Details"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "table"
        }
        name = "query - locations detail"
      }
    ]
    fallbackResourceIds = [local.law_id]
  })

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      name # Prevent recreation due to hash changes
    ]
  }
}
