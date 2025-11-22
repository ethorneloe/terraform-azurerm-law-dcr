# Conditional Access Named Locations Custom Table and DCR
# Stores Named Location configuration snapshots from Entra ID
# Named Locations are IP-based or country-based locations used in Conditional Access policies

module "conditional_access_named_locations_table" {
  source = "./modules/custom-log-table"

  table_name = "ConditionalAccessNamedLocations_CL"

  schema = {
    name = "ConditionalAccessNamedLocations_CL"
    columns = [
      # Required timestamp column
      { name = "TimeGenerated", type = "datetime", description = "The time at which the data was generated" },

      # Named Location Identity
      { name = "Id", type = "string", description = "Unique identifier (GUID) of the named location" },
      { name = "DisplayName", type = "string", description = "Display name of the named location" },

      # Timestamps
      { name = "CreatedDateTime", type = "datetime", description = "When the named location was created" },
      { name = "ModifiedDateTime", type = "datetime", description = "When the named location was last modified" },

      # Trust Status
      { name = "IsTrusted", type = "boolean", description = "Whether this location is marked as trusted (bypasses MFA)" },

      # IP-based Location Properties
      { name = "IpRanges", type = "dynamic", description = "Array of IP address ranges in CIDR notation (e.g., ['192.168.1.0/24', '10.0.0.0/8'])" },

      # Country-based Location Properties
      { name = "Countries", type = "dynamic", description = "Array of country objects with Code and Name properties (e.g., [{Code: 'US', Name: 'United States'}])" },
      { name = "IncludeUnknownCountriesAndRegions", type = "boolean", description = "Whether to include unknown countries and regions in country-based location" },
      { name = "CountryLookupMethod", type = "string", description = "Method used for country detection (clientIpAddress or authenticatorAppGps)" },
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
      Purpose    = "Conditional Access Named Locations Monitoring"
      DataSource = "Entra ID"
    }
  )
}
