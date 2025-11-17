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
      # KPI Cards Row
      {
        type = 1
        content = {
          json = "## 📊 Key Metrics"
        }
        name = "text - kpi section"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = <<-EOT
            ConditionalAccessPolicies_CL
            | where TimeGenerated {TimeRange}
            | summarize
                TotalPolicies = dcount(PolicyId),
                EnabledPolicies = dcountif(PolicyId, State == 'enabled'),
                DisabledPolicies = dcountif(PolicyId, State == 'disabled'),
                ReportOnlyPolicies = dcountif(PolicyId, State == 'enabledForReportingButNotEnforced')
            | extend EnabledPercentage = round((EnabledPolicies * 100.0) / TotalPolicies, 1)
            | project
                Metric = "Total Policies",
                Value = TotalPolicies,
                Subtext = strcat(EnabledPolicies, " enabled (", EnabledPercentage, "%)")
          EOT
          size          = 3
          title         = "Total Policies"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "tiles"
          tileSettings = {
            titleContent = {
              columnMatch = "Metric"
              formatter   = 1
            }
            leftContent = {
              columnMatch = "Value"
              formatter   = 12
              formatOptions = {
                palette = "blue"
              }
            }
            secondaryContent = {
              columnMatch = "Subtext"
              formatter   = 1
            }
            showBorder = true
          }
        }
        customWidth = "33"
        name        = "kpi - total policies"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = <<-EOT
            ConditionalAccessPolicies_CL
            | where TimeGenerated {TimeRange}
            | where State == 'enabled'
            | summarize
                PoliciesWithExemptions = countif(isnotempty(ExcludeGroups) or isnotempty(ExcludeUsers) or isnotempty(ExcludeRoles)),
                TotalEnabled = count()
            | extend ExemptionRate = round((PoliciesWithExemptions * 100.0) / TotalEnabled, 1)
            | project
                Metric = "Policies with Exemptions",
                Value = PoliciesWithExemptions,
                Subtext = strcat(ExemptionRate, "% of enabled policies")
          EOT
          size          = 3
          title         = "Exemptions"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "tiles"
          tileSettings = {
            titleContent = {
              columnMatch = "Metric"
              formatter   = 1
            }
            leftContent = {
              columnMatch = "Value"
              formatter   = 12
              formatOptions = {
                palette = "orange"
              }
            }
            secondaryContent = {
              columnMatch = "Subtext"
              formatter   = 1
            }
            showBorder = true
          }
        }
        customWidth = "33"
        name        = "kpi - exemptions"
      },
      {
        type = 3
        content = {
          version = "KqlItem/1.0"
          query   = <<-EOT
            ConditionalAccessNamedLocations_CL
            | where TimeGenerated {TimeRange}
            | summarize
                TotalLocations = dcount(LocationId),
                TrustedLocations = dcountif(LocationId, IsTrusted == true)
            | extend TrustedPercentage = round((TrustedLocations * 100.0) / TotalLocations, 1)
            | project
                Metric = "Named Locations",
                Value = TotalLocations,
                Subtext = strcat(TrustedLocations, " trusted (", TrustedPercentage, "%)")
          EOT
          size          = 3
          title         = "Named Locations"
          queryType     = 0
          resourceType  = "microsoft.operationalinsights/workspaces"
          visualization = "tiles"
          tileSettings = {
            titleContent = {
              columnMatch = "Metric"
              formatter   = 1
            }
            leftContent = {
              columnMatch = "Value"
              formatter   = 12
              formatOptions = {
                palette = "green"
              }
            }
            secondaryContent = {
              columnMatch = "Subtext"
              formatter   = 1
            }
            showBorder = true
          }
        }
        customWidth = "34"
        name        = "kpi - locations"
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
        customWidth = "40"
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
        customWidth = "60"
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
        customWidth = "40"
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
        customWidth = "60"
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
