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
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# 🔐 Conditional Access Policy Monitoring\n---\n### Real-time insights into your Conditional Access security posture\nMonitor policies, track exemptions, and analyze authentication controls across your organization."
      },
      "name": "text - hero header",
      "styleSettings": {
        "margin": "20px 0px 10px 0px",
        "showBorder": false,
        "padding": "0px"
      }
    },
    {
      "type": 9,
      "content": {
        "version": "KqlParameterItem/1.0",
        "parameters": [
          {
            "id": "timerange-param",
            "version": "KqlParameterItem/1.0",
            "name": "TimeRange",
            "label": "📅 Time Range",
            "type": 4,
            "isRequired": true,
            "value": {
              "durationMs": 604800000
            },
            "typeSettings": {
              "selectableValues": [
                { "durationMs": 86400000 },
                { "durationMs": 604800000 },
                { "durationMs": 2592000000 },
                { "durationMs": 7776000000 }
              ],
              "allowCustom": true
            }
          }
        ],
        "style": "pills",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "name": "parameters - time range"
    },

    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| summarize \n    Total = dcount(PolicyId),\n    Enabled = dcountif(PolicyId, State == 'enabled'),\n    ReportOnly = dcountif(PolicyId, State == 'enabledForReportingButNotEnforced')\n| project \n    Metric = 'Total',\n    Value = Total\n| union (\n    ConditionalAccessPolicies_CL\n    | where TimeGenerated {TimeRange}\n    | summarize Enabled = dcountif(PolicyId, State == 'enabled')\n    | project Metric = 'Enabled', Value = Enabled\n)\n| union (\n    ConditionalAccessPolicies_CL\n    | where TimeGenerated {TimeRange}\n    | summarize ReportOnly = dcountif(PolicyId, State == 'enabledForReportingButNotEnforced')\n    | project Metric = 'Report-Only', Value = ReportOnly\n)",
        "size": 4,
        "title": "Policy Overview",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "tiles",
        "tileSettings": {
          "titleContent": {
            "columnMatch": "Metric",
            "formatter": 1
          },
          "leftContent": {
            "columnMatch": "Value",
            "formatter": 12,
            "formatOptions": {
              "palette": "auto"
            },
            "numberFormat": {
              "unit": 17,
              "options": {
                "style": "decimal",
                "useGrouping": false,
                "maximumFractionDigits": 2,
                "maximumSignificantDigits": 3
              }
            }
          },
          "showBorder": true
        }
      },
      "name": "tiles - policy metrics"
    },

    {
      "type": 1,
      "content": {
        "json": "## 📋 Policy Distribution"
      },
      "name": "text - policy distribution"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| summarize Count=count() by State\n| extend StateLabel = case(\n    State == \"enabled\", \"🟢 Enabled\",\n    State == \"disabled\", \"🔴 Disabled\",\n    State == \"enabledForReportingButNotEnforced\", \"🟡 Report-Only\",\n    \"⚪ Unknown\"\n)\n| project StateLabel, Count",
        "size": 0,
        "title": "Policy State Breakdown",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "piechart",
        "chartSettings": {
          "seriesLabelSettings": [
            { "seriesName": "🟢 Enabled", "color": "green" },
            { "seriesName": "🔴 Disabled", "color": "redBright" },
            { "seriesName": "🟡 Report-Only", "color": "yellow" }
          ]
        }
      },
      "name": "chart - policies by state"
    },

    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| where State == 'enabled'\n| extend Controls = tostring(BuiltInControls)\n| where isnotempty(Controls)\n| summarize Count=count() by Controls\n| top 10 by Count desc\n| extend ControlLabel = case(\n    Controls contains \"mfa\", \"🔐 Multi-Factor Authentication\",\n    Controls contains \"compliantDevice\", \"💻 Compliant Device\",\n    Controls contains \"domainJoinedDevice\", \"🖥️ Domain Joined Device\",\n    Controls contains \"approvedApplication\", \"✅ Approved Application\",\n    Controls\n)\n| project ControlLabel, Count",
        "size": 0,
        "title": "Top Authentication Controls",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "barchart",
        "chartSettings": {
          "yAxis": [ "Count" ]
        }
      },
      "name": "chart - top controls"
    },

    {
      "type": 1,
      "content": {
        "json": "## ⏱️ Recent Activity"
      },
      "name": "text - recent activity"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ConditionalAccessPolicies_CL\n| where TimeGenerated {TimeRange}\n| extend Age = datetime_diff('day', now(), Modified)\n| extend StatusIcon = case(\n    State == 'enabled', '🟢',\n    State == 'disabled', '🔴',\n    '🟡'\n)\n| project\n    Status = StatusIcon,\n    [\"Policy Name\"] = DisplayName,\n    State,\n    [\"Last Modified\"] = format_datetime(Modified, 'yyyy-MM-dd HH:mm'),\n    [\"Days Ago\"] = Age\n| order by [\"Last Modified\"] desc\n| take 15",
        "size": 0,
        "title": "Recently Modified Policies",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "table",
        "gridSettings": {
          "formatters": [
            {
              "columnMatch": "Status",
              "formatter": 1,
              "formatOptions": { "customColumnWidthSetting": "5%" }
            },
            {
              "columnMatch": "State",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  { "operator": "==", "text": "enabled", "color": "green" },
                  { "operator": "==", "text": "disabled", "color": "redBright" },
                  { "operator": "Default", "color": "yellow" }
                ]
              }
            },
            {
              "columnMatch": "Days Ago",
              "formatter": 18,
              "formatOptions": {
                "thresholdsOptions": "colors",
                "thresholdsGrid": [
                  { "operator": "<", "value": "7", "color": "green" },
                  { "operator": "<", "value": "30", "color": "orange" },
                  { "operator": "Default", "color": "gray" }
                ]
              }
            }
          ]
        }
      },
      "name": "grid - recent modifications"
    },

    {
      "type": 1,
      "content": {
        "json": "## 🌍 Geographic Distribution"
      },
      "name": "text - geography"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ConditionalAccessNamedLocations_CL\n| where TimeGenerated {TimeRange}\n| summarize Count=count() by IsTrusted\n| extend TrustLabel = iff(IsTrusted == true, '🔒 Trusted', '⚠️ Untrusted')\n| project TrustLabel, Count",
        "size": 0,
        "title": "Location Trust Status",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "piechart",
        "chartSettings": {
          "seriesLabelSettings": [
            { "seriesName": "🔒 Trusted", "color": "green" },
            { "seriesName": "⚠️ Untrusted", "color": "orange" }
          ]
        }
      },
      "name": "chart - location trust"
    },

    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ConditionalAccessNamedLocations_CL\n| where TimeGenerated {TimeRange}\n| where isnotempty(Countries)\n| mv-expand Country = Countries\n| extend CountryCode = tostring(Country.Code)\n| where isnotempty(CountryCode)\n| summarize Count=count() by CountryCode\n| extend CountryName = case(\n    CountryCode=='US','🇺🇸 United States',\n    CountryCode=='GB','🇬🇧 United Kingdom',\n    CountryCode=='AU','🇦🇺 Australia',\n    CountryCode=='CA','🇨🇦 Canada',\n    CountryCode=='DE','🇩🇪 Germany',\n    CountryCode=='FR','🇫🇷 France',\n    CountryCode=='IN','🇮🇳 India',\n    CountryCode=='JP','🇯🇵 Japan',\n    CountryCode=='CN','🇨🇳 China',\n    CountryCode=='BR','🇧🇷 Brazil',\n    CountryCode=='NL','🇳🇱 Netherlands',\n    CountryCode=='SG','🇸🇬 Singapore',\n    CountryCode=='IE','🇮🇪 Ireland',\n    CountryCode=='NZ','🇳🇿 New Zealand',\n    CountryCode=='ZA','🇿🇦 South Africa',\n    CountryCode=='MX','🇲🇽 Mexico',\n    CountryCode=='IT','🇮🇹 Italy',\n    CountryCode=='ES','🇪🇸 Spain',\n    CountryCode=='SE','🇸🇪 Sweden',\n    CountryCode=='CH','🇨🇭 Switzerland',\n    strcat('🌍 ', CountryCode)\n)\n| project CountryName, Count\n| top 10 by Count desc",
        "size": 0,
        "title": "Top 10 Countries in Named Locations",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "barchart",
        "chartSettings": {
          "yAxis": [ "Count" ],
          "showLegend": false
        }
      },
      "name": "chart - top countries"
    },

    {
      "type": 1,
      "content": {
        "json": "## 📈 Trends"
      },
      "name": "text - trends"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ConditionalAccessPolicies_CL\n| where TimeGenerated > ago(30d)\n| summarize arg_max(TimeGenerated, *) by PolicyId\n| summarize\n    ['Total Policies'] = count(),\n    ['Enabled'] = countif(State == 'enabled'),\n    ['Disabled'] = countif(State == 'disabled'),\n    ['Report-Only'] = countif(State == 'enabledForReportingButNotEnforced')\n    by bin(TimeGenerated, 1d)",
        "size": 0,
        "title": "Policy Count Trend (Last 30 Days)",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "areachart",
        "chartSettings": {
          "yAxis": [
            "Total Policies",
            "Enabled",
            "Disabled",
            "Report-Only"
          ]
        }
      },
      "name": "chart - policy trend"
    }
  ],
  "fallbackResourceIds": [
    "YOUR-LAW-RESOURCE-ID-HERE"
  ],
  "styleSettings": {
    "paddingStyle": "wide"
  },
  "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
})

  lifecycle {
    ignore_changes = [
      name
    ]
  }
}
