# Enhanced Conditional Access Monitoring Workbook with polished visuals

resource "random_uuid" "workbook_enhanced" {}

resource "azurerm_application_insights_workbook" "conditional_access_enhanced" {
  name                = random_uuid.workbook_enhanced.result
  resource_group_name = local.rg_name
  location            = local.location
  display_name        = "Conditional Access Monitoring - Enhanced"
  source_id           = lower(local.law_id)
  category            = "workbook"

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      # Hero section with title and description
      {
        type = 1
        content = {
          json = "# 🔐 Conditional Access Policy Monitoring\n---\n### Real-time insights into your Conditional Access security posture\nMonitor policies, track exemptions, and analyze authentication controls across your organization."
        }
        name = "text - hero header"
        styleSettings = {
          margin      = "20px 0px 10px 0px"
          showBorder  = false
          padding     = "0px"
        }
      },
      # Time range parameter
      {
        type = 9
        content = {
          version = "KqlParameterItem/1.0"
          parameters = [
            {
              id           = "timerange-param"
              version      = "KqlParameterItem/1.0"
              name         = "TimeRange"
              label        = "📅 Time Range"
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
      # KPI Parameters - Direct queries for each value
      {
        type = 9
        content = {
          version = "KqlParameterItem/1.0"
          parameters = [
            {
              id                 = "total-policies-param"
              version            = "KqlParameterItem/1.0"
              name               = "TotalPolicies"
              type               = 1
              isHiddenWhenLocked = true
              query              = "ConditionalAccessPolicies_CL | where TimeGenerated {TimeRange} | summarize dcount(PolicyId)"
              queryType          = 0
              resourceType       = "microsoft.operationalinsights/workspaces"
            },
            {
              id                 = "enabled-policies-param"
              version            = "KqlParameterItem/1.0"
              name               = "EnabledPolicies"
              type               = 1
              isHiddenWhenLocked = true
              query              = "ConditionalAccessPolicies_CL | where TimeGenerated {TimeRange} | where State == 'enabled' | summarize dcount(PolicyId)"
              queryType          = 0
              resourceType       = "microsoft.operationalinsights/workspaces"
            },
            {
              id                 = "enabled-percentage-param"
              version            = "KqlParameterItem/1.0"
              name               = "EnabledPercentage"
              type               = 1
              isHiddenWhenLocked = true
              query              = "ConditionalAccessPolicies_CL | where TimeGenerated {TimeRange} | summarize TotalPolicies = dcount(PolicyId), EnabledPolicies = dcountif(PolicyId, State == 'enabled') | extend EnabledPercentage = round((EnabledPolicies * 100.0) / TotalPolicies, 1) | project EnabledPercentage"
              queryType          = 0
              resourceType       = "microsoft.operationalinsights/workspaces"
            },
            {
              id                 = "exemptions-param"
              version            = "KqlParameterItem/1.0"
              name               = "PoliciesWithExemptions"
              type               = 1
              isHiddenWhenLocked = true
              query              = "ConditionalAccessPolicies_CL | where TimeGenerated {TimeRange} | where State == 'enabled' | where isnotempty(ExcludeGroups) or isnotempty(ExcludeUsers) or isnotempty(ExcludeRoles) | summarize dcount(PolicyId)"
              queryType          = 0
              resourceType       = "microsoft.operationalinsights/workspaces"
            },
            {
              id                 = "total-locations-param"
              version            = "KqlParameterItem/1.0"
              name               = "TotalLocations"
              type               = 1
              isHiddenWhenLocked = true
              query              = "ConditionalAccessNamedLocations_CL | where TimeGenerated {TimeRange} | summarize dcount(LocationId)"
              queryType          = 0
              resourceType       = "microsoft.operationalinsights/workspaces"
            },
            {
              id                 = "trusted-locations-param"
              version            = "KqlParameterItem/1.0"
              name               = "TrustedLocations"
              type               = 1
              isHiddenWhenLocked = true
              query              = "ConditionalAccessNamedLocations_CL | where TimeGenerated {TimeRange} | where IsTrusted == true | summarize dcount(LocationId)"
              queryType          = 0
              resourceType       = "microsoft.operationalinsights/workspaces"
            },
            {
              id                 = "trusted-percentage-param"
              version            = "KqlParameterItem/1.0"
              name               = "TrustedPercentage"
              type               = 1
              isHiddenWhenLocked = true
              query              = "ConditionalAccessNamedLocations_CL | where TimeGenerated {TimeRange} | summarize TotalLocations = dcount(LocationId), TrustedLocations = dcountif(LocationId, IsTrusted == true) | extend TrustedPercentage = round((TrustedLocations * 100.0) / TotalLocations, 1) | project TrustedPercentage"
              queryType          = 0
              resourceType       = "microsoft.operationalinsights/workspaces"
            }
          ]
          style        = "pills"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
        }
        name = "parameters - kpi data"
      },
      # KPI Cards - Large Markdown Stats
      {
        type = 1
        content = {
          markdown = "## 📊 Key Metrics\n\n<div style=\"display: flex; gap: 20px; flex-wrap: wrap;\">\n  <div style=\"flex: 1; min-width: 250px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);\">\n    <div style=\"color: rgba(255,255,255,0.9); font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px;\">Total Policies</div>\n    <div style=\"color: white; font-size: 56px; font-weight: 700; line-height: 1;\">{{TotalPolicies}}</div>\n    <div style=\"color: rgba(255,255,255,0.8); font-size: 16px; margin-top: 10px;\">{{EnabledPolicies}} enabled ({{EnabledPercentage}}%)</div>\n  </div>\n\n  <div style=\"flex: 1; min-width: 250px; background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);\">\n    <div style=\"color: rgba(255,255,255,0.9); font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px;\">Policies with Exemptions</div>\n    <div style=\"color: white; font-size: 56px; font-weight: 700; line-height: 1;\">{{PoliciesWithExemptions}}</div>\n    <div style=\"color: rgba(255,255,255,0.8); font-size: 16px; margin-top: 10px;\">Active exclusions applied</div>\n  </div>\n\n  <div style=\"flex: 1; min-width: 250px; background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);\">\n    <div style=\"color: rgba(255,255,255,0.9); font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px;\">Named Locations</div>\n    <div style=\"color: white; font-size: 56px; font-weight: 700; line-height: 1;\">{{TotalLocations}}</div>\n    <div style=\"color: rgba(255,255,255,0.8); font-size: 16px; margin-top: 10px;\">{{TrustedLocations}} trusted ({{TrustedPercentage}}%)</div>\n  </div>\n</div>\n"
        }
        name = "markdown - kpi cards"
      },
      # Policy State Distribution - Enhanced Donut Chart
      {
        type = 1
        content = {
          json = "## 📋 Policy Distribution"
        }
        name = "text - policy distribution"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = <<-EOT
            ConditionalAccessPolicies_CL
            | where TimeGenerated {TimeRange}
            | summarize Count=count() by State
            | extend StateLabel = case(
                State == "enabled", "🟢 Enabled",
                State == "disabled", "🔴 Disabled",
                State == "enabledForReportingButNotEnforced", "🟡 Report-Only",
                "⚪ Unknown"
            )
            | project StateLabel, Count
          EOT
          size          = 0
          title         = "Policy State Breakdown"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "piechart"
          chartSettings = {
            seriesLabelSettings = [
              {
                seriesName = "🟢 Enabled"
                color      = "green"
              },
              {
                seriesName = "🔴 Disabled"
                color      = "redBright"
              },
              {
                seriesName = "🟡 Report-Only"
                color      = "yellow"
              }
            ]
          }
        }
        name        = "chart - policies by state"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = <<-EOT
            ConditionalAccessPolicies_CL
            | where TimeGenerated {TimeRange}
            | where State == 'enabled'
            | extend Controls = tostring(BuiltInControls)
            | where isnotempty(Controls)
            | summarize Count=count() by Controls
            | top 10 by Count desc
            | extend ControlLabel = case(
                Controls contains "mfa", "🔐 Multi-Factor Authentication",
                Controls contains "compliantDevice", "💻 Compliant Device",
                Controls contains "domainJoinedDevice", "🖥️ Domain Joined Device",
                Controls contains "approvedApplication", "✅ Approved Application",
                Controls
            )
            | project ControlLabel, Count
          EOT
          size          = 0
          title         = "Top Authentication Controls"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "barchart"
          chartSettings = {
            yAxis = ["Count"]
          }
        }
        name        = "chart - top controls"
      },
      # Recent Activity
      {
        type = 1
        content = {
          json = "## ⏱️ Recent Activity"
        }
        name = "text - recent activity"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = <<-EOT
            ConditionalAccessPolicies_CL
            | where TimeGenerated {TimeRange}
            | extend Age = datetime_diff('day', now(), Modified)
            | extend StatusIcon = case(
                State == "enabled", "🟢",
                State == "disabled", "🔴",
                "🟡"
            )
            | project
                Status = StatusIcon,
                ["Policy Name"] = DisplayName,
                State,
                ["Last Modified"] = format_datetime(Modified, 'yyyy-MM-dd HH:mm'),
                ["Days Ago"] = Age
            | order by ["Last Modified"] desc
            | take 15
          EOT
          size          = 0
          title         = "Recently Modified Policies"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "table"
          gridSettings = {
            formatters = [
              {
                columnMatch     = "Status"
                formatter       = 1
                formatOptions   = {
                  customColumnWidthSetting = "5%"
                }
              },
              {
                columnMatch = "State"
                formatter   = 18
                formatOptions = {
                  thresholdsOptions = "colors"
                  thresholdsGrid = [
                    { operator = "==", text = "enabled", color = "green" },
                    { operator = "==", text = "disabled", color = "redBright" },
                    { operator = "Default", color = "yellow" }
                  ]
                }
              },
              {
                columnMatch = "Days Ago"
                formatter   = 18
                formatOptions = {
                  thresholdsOptions = "colors"
                  thresholdsGrid = [
                    { operator = "<", value = "7", color = "green" },
                    { operator = "<", value = "30", color = "orange" },
                    { operator = "Default", color = "gray" }
                  ]
                }
              }
            ]
          }
        }
        name = "grid - recent modifications"
      },
      # Named Locations Section
      {
        type = 1
        content = {
          json = "## 🌍 Geographic Distribution"
        }
        name = "text - geography"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = <<-EOT
            ConditionalAccessNamedLocations_CL
            | where TimeGenerated {TimeRange}
            | summarize Count=count() by IsTrusted
            | extend TrustLabel = iff(IsTrusted == true, "🔒 Trusted", "⚠️ Untrusted")
            | project TrustLabel, Count
          EOT
          size          = 0
          title         = "Location Trust Status"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "piechart"
          chartSettings = {
            seriesLabelSettings = [
              {
                seriesName = "🔒 Trusted"
                color      = "green"
              },
              {
                seriesName = "⚠️ Untrusted"
                color      = "orange"
              }
            ]
          }
        }
        name        = "chart - location trust"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = <<-EOT
            ConditionalAccessNamedLocations_CL
            | where TimeGenerated {TimeRange}
            | where isnotempty(Countries)
            | mv-expand Country = Countries
            | extend CountryCode = tostring(Country.Code)
            | where isnotempty(CountryCode)
            | summarize Count=count() by CountryCode
            | extend CountryName = case(
                CountryCode == "US", "🇺🇸 United States",
                CountryCode == "GB", "🇬🇧 United Kingdom",
                CountryCode == "AU", "🇦🇺 Australia",
                CountryCode == "CA", "🇨🇦 Canada",
                CountryCode == "DE", "🇩🇪 Germany",
                CountryCode == "FR", "🇫🇷 France",
                CountryCode == "IN", "🇮🇳 India",
                CountryCode == "JP", "🇯🇵 Japan",
                CountryCode == "CN", "🇨🇳 China",
                CountryCode == "BR", "🇧🇷 Brazil",
                CountryCode == "NL", "🇳🇱 Netherlands",
                CountryCode == "SG", "🇸🇬 Singapore",
                CountryCode == "IE", "🇮🇪 Ireland",
                CountryCode == "NZ", "🇳🇿 New Zealand",
                CountryCode == "ZA", "🇿🇦 South Africa",
                CountryCode == "MX", "🇲🇽 Mexico",
                CountryCode == "IT", "🇮🇹 Italy",
                CountryCode == "ES", "🇪🇸 Spain",
                CountryCode == "SE", "🇸🇪 Sweden",
                CountryCode == "CH", "🇨🇭 Switzerland",
                strcat("🌍 ", CountryCode)
            )
            | project CountryName, Count
            | top 10 by Count desc
          EOT
          size          = 0
          title         = "Top 10 Countries in Named Locations"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "barchart"
          chartSettings = {
            yAxis      = ["Count"]
            showLegend = false
          }
        }
        name        = "chart - top countries"
      },
      # Policy Trend
      {
        type = 1
        content = {
          json = "## 📈 Trends"
        }
        name = "text - trends"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = <<-EOT
            ConditionalAccessPolicies_CL
            | where TimeGenerated > ago(30d)
            | summarize arg_max(TimeGenerated, *) by PolicyId
            | summarize
                ["Total Policies"] = count(),
                ["Enabled"] = countif(State == "enabled"),
                ["Disabled"] = countif(State == "disabled"),
                ["Report-Only"] = countif(State == "enabledForReportingButNotEnforced")
                by bin(TimeGenerated, 1d)
          EOT
          size          = 0
          title         = "Policy Count Trend (Last 30 Days)"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "areachart"
          chartSettings = {
            yAxis = ["Total Policies", "Enabled", "Disabled", "Report-Only"]
          }
        }
        name = "chart - policy trend"
      }
    ]
    fallbackResourceIds = [lower(local.law_id)]
    styleSettings = {
      paddingStyle = "wide"
    }
  })

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      name
    ]
  }
}
