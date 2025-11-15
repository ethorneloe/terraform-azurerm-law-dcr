# Conditional Access Policies Custom Table and DCR
# Stores Conditional Access policy configuration snapshots from Entra ID

module "conditional_access_policies_table" {
  source = "./modules/custom-log-table"

  table_name = "ConditionalAccessPolicies_CL"

  schema = {
    name = "ConditionalAccessPolicies_CL"
    columns = [
      # Required timestamp column
      { name = "TimeGenerated", type = "datetime", description = "The time at which the data was generated" },

      # Policy Metadata
      { name = "DisplayName", type = "string", description = "Display name of the Conditional Access policy" },
      { name = "PolicyId", type = "string", description = "Unique identifier (GUID) of the policy" },
      { name = "State", type = "string", description = "Policy state: enabled, disabled, or enabledForReportingButNotEnforced" },
      { name = "Created", type = "datetime", description = "Policy creation timestamp" },
      { name = "Modified", type = "datetime", description = "Policy last modification timestamp" },

      # Applications - Arrays of resolved app objects with Id and DisplayName
      { name = "IncludeApps", type = "dynamic", description = "Applications included in policy scope (array of objects with Id and DisplayName)" },
      { name = "ExcludeApps", type = "dynamic", description = "Applications excluded from policy scope (array of objects with Id and DisplayName)" },
      { name = "IncludeUserActions", type = "dynamic", description = "User actions included in policy scope (array of strings)" },
      { name = "ApplicationFilter", type = "string", description = "Application filter rule expression" },

      # Authentication
      { name = "AuthenticationFlows", type = "dynamic", description = "Authentication flow transfer modes (array of objects)" },

      # Client Applications / Service Principals
      { name = "ExcludeServicePrincipals", type = "dynamic", description = "Service principals excluded from policy (array of objects with Id and DisplayName)" },
      { name = "IncludeServicePrincipals", type = "dynamic", description = "Service principals included in policy (array of objects with Id and DisplayName)" },
      { name = "ServicePrincipalFilterMode", type = "string", description = "Service principal filter mode: include or exclude" },
      { name = "ServicePrincipalFilterRule", type = "string", description = "Service principal filter rule expression" },

      # Client App Types
      { name = "ClientAppTypes", type = "dynamic", description = "Client application types targeted by policy (array of strings)" },

      # Devices
      { name = "DeviceFilterMode", type = "string", description = "Device filter mode: include or exclude" },
      { name = "DeviceFilterRule", type = "string", description = "Device filter rule expression" },

      # Locations - Arrays of full named location objects
      { name = "IncludeLocations", type = "dynamic", description = "Named locations included (array of location objects with IPs/countries)" },
      { name = "ExcludeLocations", type = "dynamic", description = "Named locations excluded (array of location objects with IPs/countries)" },

      # Platforms
      { name = "IncludePlatforms", type = "dynamic", description = "Device platforms included (array of strings: android, iOS, windows, etc.)" },
      { name = "ExcludePlatforms", type = "dynamic", description = "Device platforms excluded (array of strings)" },

      # Risk Levels
      { name = "UserRiskLevels", type = "dynamic", description = "User risk levels that trigger policy (array of strings: low, medium, high)" },
      { name = "SignInRiskLevels", type = "dynamic", description = "Sign-in risk levels that trigger policy (array of strings)" },
      { name = "InsiderRiskLevels", type = "dynamic", description = "Insider risk levels that trigger policy (array of strings)" },

      # Users, Groups, and Roles - Arrays of resolved objects with Id and DisplayName
      { name = "IncludeUsers", type = "dynamic", description = "Users included in policy scope (array of objects with Id and DisplayName)" },
      { name = "ExcludeUsers", type = "dynamic", description = "Users excluded from policy scope (array of objects with Id and DisplayName)" },
      { name = "IncludeGroups", type = "dynamic", description = "Groups included in policy scope (array of objects with Id and DisplayName)" },
      { name = "ExcludeGroups", type = "dynamic", description = "Groups excluded from policy scope (array of objects with Id and DisplayName)" },
      { name = "IncludeRoles", type = "dynamic", description = "Directory roles included in policy scope (array of objects with Id and DisplayName)" },
      { name = "ExcludeRoles", type = "dynamic", description = "Directory roles excluded from policy scope (array of objects with Id and DisplayName)" },

      # Guest and External User Settings
      { name = "IncludeGuestsOrExternalUsers", type = "dynamic", description = "Guest/external user inclusion settings (object)" },
      { name = "ExcludeGuestsOrExternalUsers", type = "dynamic", description = "Guest/external user exclusion settings (object)" },
      { name = "IncludeExternalTenantsMembershipKind", type = "string", description = "External tenants membership kind for inclusion: all, enumerated" },
      { name = "IncludeExternalTenantsMembers", type = "dynamic", description = "Specific external tenant IDs included (array of strings)" },
      { name = "ExcludeExternalTenantsMembershipKind", type = "string", description = "External tenants membership kind for exclusion" },
      { name = "ExcludeExternalTenantsMembers", type = "dynamic", description = "Specific external tenant IDs excluded (array of strings)" },

      # Grant Controls
      { name = "BuiltInControls", type = "dynamic", description = "Built-in grant controls required (array of strings: mfa, compliantDevice, etc.)" },
      { name = "CustomAuthenticationFactors", type = "dynamic", description = "Custom authentication factors (array of strings)" },
      { name = "TermsOfUse", type = "dynamic", description = "Terms of Use agreements required (array of objects with Id and DisplayName)" },
      { name = "Operator", type = "string", description = "Grant controls operator: AND or OR" },
      { name = "AuthenticationStrengthId", type = "string", description = "Authentication strength policy ID (GUID)" },
      { name = "AuthenticationStrengthDisplayName", type = "string", description = "Authentication strength policy display name" },
      { name = "AuthenticationStrengthPolicyType", type = "string", description = "Authentication strength policy type: builtIn or custom" },
      { name = "AuthenticationStrengthAllowedCombinations", type = "dynamic", description = "Allowed authentication method combinations (array of strings)" },
      { name = "AuthenticationStrengthRequirementsSatisfied", type = "string", description = "Requirements satisfaction mode" },

      # Session Controls
      { name = "ApplicationEnforcedRestrictionsIsEnabled", type = "boolean", description = "Whether application enforced restrictions are enabled" },
      { name = "CloudAppSecurityType", type = "string", description = "Cloud app security control type: mcasConfigured, monitorOnly, blockDownloads" },
      { name = "CloudAppSecurityIsEnabled", type = "boolean", description = "Whether cloud app security controls are enabled" },
      { name = "DisableResilienceDefaults", type = "boolean", description = "Whether resilience defaults are disabled" },
      { name = "PersistentBrowserIsEnabled", type = "boolean", description = "Whether persistent browser session control is enabled" },
      { name = "PersistentBrowserMode", type = "string", description = "Persistent browser mode: always or never" },
      { name = "SignInFrequencyAuthenticationType", type = "string", description = "Sign-in frequency authentication type: primaryAndSecondaryAuthentication or secondaryAuthentication" },
      { name = "SignInFrequencyInterval", type = "string", description = "Sign-in frequency interval: timeBased or everyTime" },
      { name = "SignInFrequencyIsEnabled", type = "boolean", description = "Whether sign-in frequency control is enabled" },
      { name = "SignInFrequencyType", type = "string", description = "Sign-in frequency type: days or hours" },
      { name = "SignInFrequencyValue", type = "int", description = "Sign-in frequency value (number of days or hours)" },
    ]
  }

  log_analytics_workspace_id  = local.law_id
  data_collection_endpoint_id = local.dce_id
  resource_group_name         = local.rg_name
  location                    = local.location

  # Use Analytics plan for historical analysis and longer retention
  table_plan              = "Analytics"
  retention_in_days       = 90  # Hot tier: 90 days of fast queries
  total_retention_in_days = 365 # Total: 1 year including archive tier

  # Pass through data without transformation
  transform_kql = "source"

  tags = merge(
    var.tags,
    {
      Purpose    = "Conditional Access Policy Monitoring"
      DataSource = "Entra ID"
    }
  )
}
