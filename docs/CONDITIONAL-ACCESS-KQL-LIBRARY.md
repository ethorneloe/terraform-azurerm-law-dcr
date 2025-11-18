# Conditional Access KQL Query Library

**46 production-ready KQL queries** for building Grafana dashboards and Azure Monitor workbooks. Organized by visualization type and use case.

All queries have been validated via the Log Analytics API and include null-safety protections.

---

## 📊 SINGLE STAT QUERIES (for metric tiles)

### 1. Total Active Policies
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by PolicyId
| where State == "enabled"
| summarize TotalPolicies = count()
```

### 2. Report-Only Policies Count
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by PolicyId
| where State == "enabledForReportingButNotEnforced"
| summarize ReportOnlyPolicies = count()
```

### 3. Total Exempted Users (across all policies)
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(ExcludeUsers)
| mv-expand User = ExcludeUsers
| extend UserId = tostring(User.Id)
| where isnotempty(UserId) and UserId != "All"
| summarize UniqueExemptedUsers = dcount(UserId)
```

### 4. Total Exempted Groups
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(ExcludeGroups)
| mv-expand Group = ExcludeGroups
| extend GroupId = tostring(Group.Id)
| where isnotempty(GroupId)
| summarize UniqueExemptedGroups = dcount(GroupId)
```

### 5. Policies with MFA Requirement
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where BuiltInControls has "mfa"
| summarize MFAPolicies = dcount(PolicyId)
```

### 6. Policies Requiring Compliant Devices
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where BuiltInControls has "compliantDevice"
| summarize CompliantDevicePolicies = dcount(PolicyId)
```

### 7. Total Named Locations
```kql
ConditionalAccessNamedLocations_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by Id
| summarize TotalLocations = count()
```

### 8. Trusted Locations Count
```kql
ConditionalAccessNamedLocations_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by Id
| where IsTrusted == true
| summarize TrustedLocations = count()
```

### 9. Policies Modified in Last 7 Days
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by PolicyId
| where Modified > ago(7d)
| summarize RecentlyModified = count()
```

### 10. Average Exemptions Per Policy
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| extend TotalExemptions = coalesce(array_length(ExcludeGroups), 0)
                         + coalesce(array_length(ExcludeUsers), 0)
                         + coalesce(array_length(ExcludeRoles), 0)
| summarize AvgExemptions = round(avg(TotalExemptions), 1)
```

---

## 🥧 PIE CHART QUERIES

### 11. Policy State Distribution
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by PolicyId
| summarize Count = count() by State
| extend StateLabel = case(
    State == "enabled", "Enabled",
    State == "disabled", "Disabled",
    State == "enabledForReportingButNotEnforced", "Report-Only",
    "Unknown"
)
| project StateLabel, Count
```

### 12. Policies by Grant Control Type
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(BuiltInControls)
| mv-expand Control = BuiltInControls
| extend ControlType = tostring(Control)
| summarize Count = count() by ControlType
| extend ControlLabel = case(
    ControlType == "mfa", "Multi-Factor Authentication",
    ControlType == "compliantDevice", "Compliant Device",
    ControlType == "domainJoinedDevice", "Domain Joined Device",
    ControlType == "approvedApplication", "Approved Application",
    ControlType == "compliantApplication", "Compliant Application",
    ControlType
)
| project ControlLabel, Count
```

### 13. Platform Distribution
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(IncludePlatforms)
| mv-expand Platform = IncludePlatforms
| extend PlatformType = tostring(Platform)
| summarize Count = count() by PlatformType
| project PlatformType, Count
```

### 14. Client App Type Distribution
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(ClientAppTypes)
| mv-expand AppType = ClientAppTypes
| extend ClientType = tostring(AppType)
| summarize Count = count() by ClientType
| project ClientType, Count
```

### 15. Location Trust Status
```kql
ConditionalAccessNamedLocations_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by Id
| summarize Count = count() by IsTrusted
| extend TrustStatus = iff(IsTrusted == true, "Trusted", "Untrusted")
| project TrustStatus, Count
```

---

## 📊 BAR CHART QUERIES

### 16. Top 10 Most Exempted Groups
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(ExcludeGroups)
| mv-expand Group = ExcludeGroups
| extend GroupId = tostring(Group.Id), GroupName = tostring(Group.DisplayName)
| where isnotempty(GroupId)
| summarize PolicyCount = dcount(PolicyId) by GroupName
| top 10 by PolicyCount desc
| project GroupName, PolicyCount
```

### 17. Top Applications with Exemptions
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(ExcludeApps)
| mv-expand App = ExcludeApps
| extend AppId = tostring(App.Id), AppName = tostring(App.DisplayName)
| where isnotempty(AppId)
| summarize PolicyCount = dcount(PolicyId) by AppName
| top 10 by PolicyCount desc
| project AppName, PolicyCount
```

### 18. Policies by Risk Level Configuration
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(SignInRiskLevels) or isnotempty(UserRiskLevels)
| extend RiskType = case(
    isnotempty(SignInRiskLevels) and isnotempty(UserRiskLevels), "Both Sign-in & User Risk",
    isnotempty(SignInRiskLevels), "Sign-in Risk Only",
    isnotempty(UserRiskLevels), "User Risk Only",
    "No Risk Conditions"
)
| summarize Count = count() by RiskType
| project RiskType, Count
```

### 19. Top 10 Countries in Named Locations
```kql
ConditionalAccessNamedLocations_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by Id
| where isnotempty(Countries)
| mv-expand Country = Countries
| extend CountryCode = tostring(Country.Code)
| where isnotempty(CountryCode)
| summarize Count = count() by CountryCode
| top 10 by Count desc
| project CountryCode, Count
```

### 20. Session Control Usage
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| extend SessionControls = pack_array(
    iff(SignInFrequencyIsEnabled == true, "Sign-in Frequency", ""),
    iff(PersistentBrowserIsEnabled == true, "Persistent Browser", ""),
    iff(CloudAppSecurityIsEnabled == true, "Cloud App Security", ""),
    iff(ApplicationEnforcedRestrictionsIsEnabled == true, "App Enforced Restrictions", "")
)
| mv-expand SessionControl = SessionControls
| extend Control = tostring(SessionControl)
| where isnotempty(Control)
| summarize Count = count() by Control
| project Control, Count
```

---

## 📋 TABLE QUERIES

### 21. All Users in Exemption Groups (with their policies)
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(ExcludeGroups)
| mv-expand Group = ExcludeGroups
| extend GroupId = tostring(Group.Id), GroupName = tostring(Group.DisplayName)
| where isnotempty(GroupId)
| project
    PolicyName = DisplayName,
    PolicyId,
    ExemptedGroupName = GroupName,
    ExemptedGroupId = GroupId,
    PolicyState = State,
    RequiredControls = BuiltInControls,
    Modified
| order by ExemptedGroupName asc, PolicyName asc
```

### 22. All Exempted Applications with Policy Details
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(ExcludeApps)
| mv-expand App = ExcludeApps
| extend AppId = tostring(App.Id), AppName = tostring(App.DisplayName)
| where isnotempty(AppId)
| project
    PolicyName = DisplayName,
    ExemptedApplication = AppName,
    ApplicationId = AppId,
    PolicyRequirements = BuiltInControls,
    PolicyState = State,
    Modified
| order by ExemptedApplication asc
```

### 23. Named Locations Usage by Policies
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(IncludeLocations) or isnotempty(ExcludeLocations)
| mv-expand Location = iff(isnotempty(IncludeLocations), IncludeLocations, ExcludeLocations)
| extend
    LocationId = tostring(Location.Id),
    LocationName = tostring(Location.DisplayName),
    LocationType = iff(isnotempty(IncludeLocations), "Included", "Excluded")
| where isnotempty(LocationId)
| project
    PolicyName = DisplayName,
    LocationName,
    LocationId,
    UsageType = LocationType,
    PolicyState = State
| order by LocationName asc, PolicyName asc
```

### 24. IP Ranges in Each Named Location
```kql
ConditionalAccessNamedLocations_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by Id
| where isnotempty(IpRanges)
| mv-expand IpRange = IpRanges
| extend IPAddress = tostring(IpRange)
| project
    LocationName = DisplayName,
    LocationId = Id,
    IPRange = IPAddress,
    IsTrusted,
    Modified = ModifiedDateTime
| order by LocationName asc
```

### 25. Policies Filtering by Roles (and which roles)
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(IncludeRoles) or isnotempty(ExcludeRoles)
| extend RoleType = case(
    isnotempty(IncludeRoles) and isnotempty(ExcludeRoles), "Both Include & Exclude",
    isnotempty(IncludeRoles), "Include Only",
    "Exclude Only"
)
| mv-expand Role = iff(isnotempty(IncludeRoles), IncludeRoles, ExcludeRoles)
| extend
    RoleId = tostring(Role.Id),
    RoleName = tostring(Role.DisplayName),
    RoleUsage = iff(isnotempty(IncludeRoles), "Included", "Excluded")
| where isnotempty(RoleId)
| project
    PolicyName = DisplayName,
    RoleName,
    RoleUsage,
    RequiredControls = BuiltInControls,
    PolicyState = State
| order by RoleName asc, PolicyName asc
```

### 26. Policies with Authentication Strength Requirements
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(AuthenticationStrengthId)
| project
    PolicyName = DisplayName,
    AuthStrengthName = AuthenticationStrengthDisplayName,
    AuthStrengthType = AuthenticationStrengthPolicyType,
    AllowedMethods = AuthenticationStrengthAllowedCombinations,
    PolicyState = State,
    Modified
| order by PolicyName asc
```

### 27. Direct User Exemptions (non-group based)
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(ExcludeUsers)
| mv-expand User = ExcludeUsers
| extend UserId = tostring(User.Id), UserName = tostring(User.DisplayName)
| where isnotempty(UserId) and UserId != "All" and UserId != "GuestsOrExternalUsers"
| project
    PolicyName = DisplayName,
    ExemptedUser = UserName,
    UserId,
    PolicyRequirements = BuiltInControls,
    Modified
| order by ExemptedUser asc, PolicyName asc
```

### 28. Policies Targeting External/Guest Users
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(IncludeGuestsOrExternalUsers) or isnotempty(ExcludeGuestsOrExternalUsers)
| extend
    GuestInclusion = iff(isnotempty(IncludeGuestsOrExternalUsers), "Yes", "No"),
    GuestExclusion = iff(isnotempty(ExcludeGuestsOrExternalUsers), "Yes", "No")
| project
    PolicyName = DisplayName,
    GuestInclusion,
    GuestExclusion,
    IncludeDetails = IncludeGuestsOrExternalUsers,
    ExcludeDetails = ExcludeGuestsOrExternalUsers,
    RequiredControls = BuiltInControls
| order by PolicyName asc
```

### 29. Service Principal Policies
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(IncludeServicePrincipals) or isnotempty(ExcludeServicePrincipals)
| mv-expand SP = iff(isnotempty(IncludeServicePrincipals), IncludeServicePrincipals, ExcludeServicePrincipals)
| extend
    ServicePrincipalId = tostring(SP.Id),
    ServicePrincipalName = tostring(SP.DisplayName),
    SPUsage = iff(isnotempty(IncludeServicePrincipals), "Included", "Excluded")
| where isnotempty(ServicePrincipalId)
| project
    PolicyName = DisplayName,
    ServicePrincipalName,
    ServicePrincipalId,
    Usage = SPUsage,
    FilterMode = ServicePrincipalFilterMode,
    FilterRule = ServicePrincipalFilterRule
| order by ServicePrincipalName asc
```

### 30. Policies with Device Filters
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(DeviceFilterRule)
| project
    PolicyName = DisplayName,
    DeviceFilterMode,
    DeviceFilterRule,
    RequiredControls = BuiltInControls,
    Modified
| order by PolicyName asc
```

---

## 📈 TIME SERIES / LINE CHART QUERIES

### 31. Policy State Changes Over Time
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by PolicyId, bin(TimeGenerated, 1d)
| summarize
    Enabled = countif(State == "enabled"),
    Disabled = countif(State == "disabled"),
    ReportOnly = countif(State == "enabledForReportingButNotEnforced")
    by bin(TimeGenerated, 1d)
| project TimeGenerated, Enabled, Disabled, ReportOnly
| order by TimeGenerated asc
```

### 32. Exemption Growth Trend
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| extend TotalExemptions = coalesce(array_length(ExcludeGroups), 0)
                         + coalesce(array_length(ExcludeUsers), 0)
                         + coalesce(array_length(ExcludeRoles), 0)
| summarize AvgExemptions = avg(TotalExemptions) by bin(TimeGenerated, 1d)
| project TimeGenerated, AvgExemptions
| order by TimeGenerated asc
```

### 33. MFA Policy Coverage Over Time
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| extend HasMFA = iff(BuiltInControls has "mfa", 1, 0)
| summarize
    TotalPolicies = dcount(PolicyId),
    MFAPolicies = dcountif(PolicyId, HasMFA == 1)
    by bin(TimeGenerated, 1d)
| extend MFACoveragePercent = round((MFAPolicies * 100.0) / TotalPolicies, 1)
| project TimeGenerated, MFACoveragePercent
| order by TimeGenerated asc
```

---

## 🔍 ADVANCED ANALYTICS QUERIES

### 34. Exemption Risk Score by Policy
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| extend
    ExemptGroups = coalesce(array_length(ExcludeGroups), 0),
    ExemptUsers = coalesce(array_length(ExcludeUsers), 0),
    ExemptRoles = coalesce(array_length(ExcludeRoles), 0),
    HasMFA = iff(BuiltInControls has "mfa", 1, 0),
    HasDeviceCompliance = iff(BuiltInControls has "compliantDevice", 1, 0)
| extend RiskScore =
    (ExemptGroups * 3) +      // Group exemptions are risky
    (ExemptUsers * 5) +        // Direct user exemptions more risky
    (ExemptRoles * 10) +       // Role exemptions highest risk
    (HasMFA * -5) +            // MFA reduces risk
    (HasDeviceCompliance * -3) // Device compliance reduces risk
| project
    PolicyName = DisplayName,
    RiskScore,
    ExemptGroups,
    ExemptUsers,
    ExemptRoles,
    Controls = BuiltInControls
| order by RiskScore desc
| take 20
```

### 35. Coverage Gap Analysis (Unprotected Apps)
```kql
// Apps that are excluded from MFA policies
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where BuiltInControls has "mfa"
| where isnotempty(ExcludeApps)
| mv-expand App = ExcludeApps
| extend AppId = tostring(App.Id), AppName = tostring(App.DisplayName)
| summarize
    ExemptedFromMFAPolicies = make_list(DisplayName),
    MFAPolicyCount = count()
    by AppName, AppId
| project AppName, MFAPolicyCount, ExemptedFromMFAPolicies
| order by MFAPolicyCount desc
```

### 36. Stale Policies (not modified in 90+ days)
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by PolicyId
| extend DaysSinceModified = datetime_diff('day', now(), Modified)
| where DaysSinceModified > 90
| project
    PolicyName = DisplayName,
    State,
    DaysSinceModified,
    LastModified = Modified,
    Controls = BuiltInControls
| order by DaysSinceModified desc
```

### 37. Policy Complexity Score
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| extend ComplexityScore =
    coalesce(array_length(IncludeApps), 0) +
    coalesce(array_length(ExcludeApps), 0) +
    coalesce(array_length(IncludeGroups), 0) +
    coalesce(array_length(ExcludeGroups), 0) +
    coalesce(array_length(IncludeRoles), 0) +
    coalesce(array_length(ExcludeRoles), 0) +
    coalesce(array_length(IncludeLocations), 0) +
    coalesce(array_length(ExcludeLocations), 0) +
    coalesce(array_length(BuiltInControls), 0)
| project
    PolicyName = DisplayName,
    ComplexityScore,
    State,
    Modified
| order by ComplexityScore desc
```

### 38. Orphaned Named Locations (not used in any policy)
```kql
let UsedLocations =
    ConditionalAccessPolicies_CL
    | where TimeGenerated {TimeRange}
    | where State == "enabled"
    | mv-expand Location = array_concat(
        coalesce(IncludeLocations, dynamic([])),
        coalesce(ExcludeLocations, dynamic([]))
    )
    | extend LocationId = tostring(Location.Id)
    | where isnotempty(LocationId)
    | summarize by LocationId;
ConditionalAccessNamedLocations_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by Id
| where Id !in (UsedLocations)
| project
    LocationName = DisplayName,
    LocationId = Id,
    IsTrusted,
    IpRanges,
    Countries,
    LastModified = ModifiedDateTime,
    Status = "Orphaned - Not Used in Any Policy"
| order by LocationName asc
```

### 39. Authentication Method Distribution
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(AuthenticationStrengthAllowedCombinations)
| mv-expand Method = AuthenticationStrengthAllowedCombinations
| extend AuthMethod = tostring(Method)
| summarize PolicyCount = count() by AuthMethod
| order by PolicyCount desc
```

### 40. Policies by Grant Operator (AND vs OR)
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where isnotempty(BuiltInControls)
| extend OperatorType = iff(Operator == "AND", "Require ALL controls", "Require ANY control")
| summarize
    PolicyCount = count(),
    Policies = make_list(DisplayName)
    by OperatorType
| project OperatorType, PolicyCount, SamplePolicies = Policies
```

---

## 🚨 CRITICAL SECURITY INSIGHTS (Game-Changing Queries)

### 41. The "Shadow Admin" Detector - Users Exempted from ALL MFA Policies
```kql
// CRITICAL: Finds users who effectively bypass MFA entirely
let MFAPolicies =
    ConditionalAccessPolicies_CL
    | where TimeGenerated {TimeRange}
    | where State == "enabled"
    | where BuiltInControls has "mfa"
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | summarize MFAPolicyCount = count();
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| where BuiltInControls has "mfa"
| summarize arg_max(TimeGenerated, *) by PolicyId
| where isnotempty(ExcludeUsers) or isnotempty(ExcludeGroups)
// Expand both users and groups
| extend AllExemptedIdentities = array_concat(
    coalesce(ExcludeUsers, dynamic([])),
    coalesce(ExcludeGroups, dynamic([]))
)
| mv-expand Identity = AllExemptedIdentities
| extend
    IdentityId = tostring(Identity.Id),
    IdentityName = tostring(Identity.DisplayName),
    IdentityType = case(
        isnotempty(tostring(Identity.userPrincipalName)), "User",
        "Group"
    )
| where isnotempty(IdentityId) and IdentityId != "All"
| summarize
    ExemptedFromMFAPolicies = make_set(DisplayName),
    MFAPolicyExemptionCount = count()
    by IdentityName, IdentityId, IdentityType
| extend MFAPolicyCount = toscalar(MFAPolicies)
| where MFAPolicyExemptionCount == MFAPolicyCount
| project
    Alert = "CRITICAL",
    Identity = IdentityName,
    Type = IdentityType,
    MFABypassStatus = "COMPLETELY EXEMPT FROM ALL MFA",
    ExemptedFromPolicies = ExemptedFromMFAPolicies,
    TotalMFAPolicies = MFAPolicyCount,
    RiskLevel = "EXTREME"
| order by Type desc, Identity asc
```

### 42. "Blast Radius Calculator" - What Gets Compromised if Group X is Breached
```kql
// Shows the full impact if a specific exemption group is compromised
// FIXED: Removed hardcoded variable, added null safety and type safety
// NOTE: Replace 'YOUR_GROUP_NAME' with the actual group name when using this query
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| summarize arg_max(TimeGenerated, *) by PolicyId
| where isnotempty(coalesce(ExcludeGroups, dynamic([])))
| mv-expand Group = coalesce(ExcludeGroups, dynamic([])) to typeof(dynamic)
| extend GroupName = tostring(Group.DisplayName)
| where GroupName == "YOUR_GROUP_NAME"  // CHANGE THIS WHEN USING
| extend
    BypassesMFA = toint(iff(BuiltInControls has "mfa", 1, 0)),
    BypassesDeviceCompliance = toint(iff(BuiltInControls has "compliantDevice", 1, 0)),
    BypassesHybridJoin = toint(iff(BuiltInControls has "domainJoinedDevice", 1, 0)),
    AffectedApps = toint(coalesce(array_length(IncludeApps), 0)),
    AffectedUsers = toint(coalesce(array_length(IncludeUsers), 0)),
    AffectedRoles = toint(coalesce(array_length(IncludeRoles), 0)),
    HasSignInFreq = toint(iff(SignInFrequencyIsEnabled == true, 1, 0)),
    HasPersistentBrowser = toint(iff(PersistentBrowserIsEnabled == true, 1, 0)),
    HasCloudAppSec = toint(iff(CloudAppSecurityIsEnabled == true, 1, 0))
| summarize
    PoliciesBypassed = count(),
    MFABypassCount = sum(BypassesMFA),
    DeviceBypassCount = sum(BypassesDeviceCompliance),
    TotalAffectedApps = sum(AffectedApps),
    ControlsBypassed = make_set(BuiltInControls),
    PoliciesAffected = make_list(DisplayName),
    SessionControlCount = sum(HasSignInFreq) + sum(HasPersistentBrowser) + sum(HasCloudAppSec)
| extend
    BlastRadiusScore = toint((MFABypassCount * 100) + (DeviceBypassCount * 50) + (PoliciesBypassed * 10)),
    ThreatLevel = case(
        (MFABypassCount * 100) + (DeviceBypassCount * 50) + (PoliciesBypassed * 10) > 200, "CATASTROPHIC",
        (MFABypassCount * 100) + (DeviceBypassCount * 50) + (PoliciesBypassed * 10) > 100, "SEVERE",
        (MFABypassCount * 100) + (DeviceBypassCount * 50) + (PoliciesBypassed * 10) > 50, "HIGH",
        "MODERATE"
    )
| project
    CompromisedGroup = "YOUR_GROUP_NAME",
    ThreatLevel,
    BlastRadiusScore,
    PoliciesBypassed,
    MFAPoliciesBypassed = MFABypassCount,
    DeviceComplianceBypassed = DeviceBypassCount,
    EstimatedAffectedApps = TotalAffectedApps,
    SecurityControlsNeutralized = ControlsBypassed,
    PoliciesImpacted = PoliciesAffected,
    SessionControlsAffected = SessionControlCount
```

### 43. "Anomaly Hunter" - Statistical Outliers in Exemption Patterns
```kql
// Uses statistical analysis to find policies with abnormal exemption counts
let PolicyStats =
    ConditionalAccessPolicies_CL
    | where TimeGenerated {TimeRange}
    | where State == "enabled"
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend TotalExemptions =
        coalesce(array_length(ExcludeGroups), 0) +
        coalesce(array_length(ExcludeUsers), 0) +
        coalesce(array_length(ExcludeRoles), 0) +
        coalesce(array_length(ExcludeApps), 0)
    | summarize
        AvgExemptions = avg(TotalExemptions),
        StdDev = stdev(TotalExemptions),
        MaxExemptions = max(TotalExemptions);
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| summarize arg_max(TimeGenerated, *) by PolicyId
| extend TotalExemptions =
    coalesce(array_length(ExcludeGroups), 0) +
    coalesce(array_length(ExcludeUsers), 0) +
    coalesce(array_length(ExcludeRoles), 0) +
    coalesce(array_length(ExcludeApps), 0)
| extend
    AvgExemptions = toscalar(PolicyStats | project AvgExemptions),
    StdDev = toscalar(PolicyStats | project StdDev)
| extend StandardDeviationsFromMean = round((TotalExemptions - AvgExemptions) / StdDev, 2)
| where StandardDeviationsFromMean > 2.0  // 2+ standard deviations = outlier
| extend AnomalyLevel = case(
    StandardDeviationsFromMean > 3.0, "EXTREME OUTLIER (3+ sigma)",
    StandardDeviationsFromMean > 2.5, "SEVERE OUTLIER (2.5+ sigma)",
    "MODERATE OUTLIER (2+ sigma)"
)
| project
    AnomalyLevel,
    PolicyName = DisplayName,
    TotalExemptions,
    StandardDeviationsFromMean,
    ExemptGroups = coalesce(array_length(ExcludeGroups), 0),
    ExemptUsers = coalesce(array_length(ExcludeUsers), 0),
    ExemptRoles = coalesce(array_length(ExcludeRoles), 0),
    ExemptApps = coalesce(array_length(ExcludeApps), 0),
    Controls = BuiltInControls,
    LastModified = Modified,
    InvestigationPriority = case(
        BuiltInControls has "mfa" and StandardDeviationsFromMean > 2.5, "URGENT",
        BuiltInControls has "mfa", "HIGH",
        "MEDIUM"
    )
| order by StandardDeviationsFromMean desc
```

### 44. "Time Bomb Detector" - Report-Only Policies Never Promoted to Enforcement
```kql
// Finds report-only policies that have been in that state for 30+ days - decision paralysis indicator
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| summarize arg_max(TimeGenerated, *) by PolicyId
| where State == "enabledForReportingButNotEnforced"
| extend
    DaysSinceCreation = datetime_diff('day', now(), Created),
    DaysSinceModification = datetime_diff('day', now(), Modified)
| where DaysSinceCreation > 30
| extend StagnationCategory = case(
    DaysSinceCreation > 180, "ABANDONED (6+ months)",
    DaysSinceCreation > 90, "STAGNANT (3+ months)",
    "LINGERING (30+ days)"
)
| project
    StagnationCategory,
    PolicyName = DisplayName,
    DaysSinceCreation,
    DaysSinceLastModification = DaysSinceModification,
    CreatedOn = Created,
    LastTouched = Modified,
    Controls = BuiltInControls,
    AffectedUsers = coalesce(array_length(IncludeUsers), 0),
    AffectedGroups = coalesce(array_length(IncludeGroups), 0),
    ActionNeeded = "Review and either ENFORCE or DELETE",
    RiskOfInaction = case(
        BuiltInControls has "mfa", "High - MFA not enforced",
        BuiltInControls has "compliantDevice", "Medium - Device compliance not enforced",
        "Low - Consider cleanup"
    )
| order by DaysSinceCreation desc
```

### 45. "Compliance Nightmare Matrix" - Policies Missing Critical Controls
```kql
// Identifies gaps in security posture across policy portfolio
// FIXED: Safe field access with proper type conversion
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| summarize arg_max(TimeGenerated, *) by PolicyId
| extend
    HasMFA = toint(iff(BuiltInControls has "mfa", 1, 0)),
    HasCompliantDevice = toint(iff(BuiltInControls has "compliantDevice", 1, 0)),
    HasDomainJoin = toint(iff(BuiltInControls has "domainJoinedDevice", 1, 0)),
    HasTOU = toint(iff(isnotempty(coalesce(TermsOfUse, dynamic([]))), 1, 0)),
    HasSignInRisk = toint(iff(isnotempty(coalesce(SignInRiskLevels, dynamic([]))), 1, 0)),
    HasUserRisk = toint(iff(isnotempty(coalesce(UserRiskLevels, dynamic([]))), 1, 0)),
    HasLocationFilter = toint(iff(isnotempty(coalesce(IncludeLocations, dynamic([]))) or isnotempty(coalesce(ExcludeLocations, dynamic([]))), 1, 0)),
    HasPlatformFilter = toint(iff(isnotempty(coalesce(IncludePlatforms, dynamic([]))), 1, 0)),
    HasSessionControls = toint(iff(
        SignInFrequencyIsEnabled == true or
        PersistentBrowserIsEnabled == true or
        CloudAppSecurityIsEnabled == true, 1, 0)),
    AffectsAllUsers = toint(iff(BuiltInControls has "All" or IncludeUsers has "All", 1, 0))
| extend
    SecurityScore = toint((HasMFA * 25) + (HasCompliantDevice * 20) + (HasSignInRisk * 15) +
                    (HasUserRisk * 15) + (HasLocationFilter * 10) + (HasSessionControls * 10) + (HasTOU * 5)),
    MissingMFA = toint(iff(HasMFA == 0, 1, 0)),
    MissingDevice = toint(iff(HasCompliantDevice == 0, 1, 0)),
    MissingSignInRisk = toint(iff(HasSignInRisk == 0, 1, 0)),
    MissingUserRisk = toint(iff(HasUserRisk == 0, 1, 0)),
    MissingLocation = toint(iff(HasLocationFilter == 0, 1, 0)),
    MissingSession = toint(iff(HasSessionControls == 0, 1, 0))
| extend ComplianceGrade = case(
    SecurityScore >= 80, "A - Strong",
    SecurityScore >= 60, "B - Adequate",
    SecurityScore >= 40, "C - Weak",
    "D - Critical Gaps"
)
| where SecurityScore < 60
| project
    ComplianceGrade,
    PolicyName = DisplayName,
    SecurityScore,
    MissingMFA,
    MissingCompliantDevice = MissingDevice,
    MissingSignInRisk,
    MissingUserRisk,
    MissingLocationFilter = MissingLocation,
    MissingSessionControls = MissingSession,
    CurrentControls = BuiltInControls,
    AffectsAllUsers,
    AffectedAppCount = toint(coalesce(array_length(IncludeApps), 0)),
    ExemptionCount = toint(coalesce(array_length(ExcludeGroups), 0) + coalesce(array_length(ExcludeUsers), 0)),
    RemediationUrgency = case(
        AffectsAllUsers == 1 and SecurityScore < 40, "URGENT",
        SecurityScore < 40, "HIGH",
        "MEDIUM"
    )
| order by SecurityScore asc
```

### 46. "Guest Access Nightmare" - External Users with Privileged Access Exemptions
```kql
// Detects the dangerous combination of guest access + control exemptions
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| summarize arg_max(TimeGenerated, *) by PolicyId
| where (IncludeUsers has "GuestsOrExternalUsers" or isnotempty(IncludeGuestsOrExternalUsers))
    and (isnotempty(ExcludeGroups) or isnotempty(ExcludeUsers) or isnotempty(ExcludeRoles))
| extend
    GuestInclusionType = case(
        IncludeUsers has "GuestsOrExternalUsers", "All Guests",
        isnotempty(IncludeGuestsOrExternalUsers), tostring(IncludeGuestsOrExternalUsers),
        "Unknown"
    ),
    ExemptGroupCount = coalesce(array_length(ExcludeGroups), 0),
    ExemptUserCount = coalesce(array_length(ExcludeUsers), 0),
    ExemptRoleCount = coalesce(array_length(ExcludeRoles), 0),
    RiskScore =
        (iff(BuiltInControls has "mfa", 50, 0)) +
        (iff(BuiltInControls has "compliantDevice", 30, 0)) +
        (coalesce(array_length(ExcludeGroups), 0) * 10) +
        (coalesce(array_length(ExcludeUsers), 0) * 15) +
        (coalesce(array_length(ExcludeRoles), 0) * 25)
| extend ThreatLevel = case(
    RiskScore > 100, "CRITICAL - Guests can bypass major controls",
    RiskScore > 50, "HIGH - Significant guest exemption risk",
    "MEDIUM - Review guest access pattern"
)
| project
    ThreatLevel,
    PolicyName = DisplayName,
    RiskScore,
    GuestInclusionType,
    ExemptGroupCount,
    ExemptUserCount,
    ExemptRoleCount,
    BypassedControls = BuiltInControls,
    ExemptedGroups = ExcludeGroups,
    ExemptedUsers = ExcludeUsers,
    ExemptedRoles = ExcludeRoles,
    ExternalTenantAccess = IncludeExternalTenantsMembers,
    Modified,
    RecommendedAction = "Review if guests should have these exemptions - potential data exfiltration risk"
| order by RiskScore desc
```

---

## 💡 Usage Tips for Grafana

### Time Range Variable
Most queries use `{TimeRange}` which should be defined as a Grafana variable:
- Variable name: `TimeRange`
- Type: Interval
- Default: `ago(7d)`

### Query Optimization
1. Always filter by `TimeGenerated {TimeRange}` first
2. Use `summarize arg_max(TimeGenerated, *) by PolicyId` to get latest snapshot
3. For real-time dashboards, use shorter time ranges (1h, 6h, 24h)

### Visualization Mappings
- **Single Stat**: Queries 1-10
- **Pie Charts**: Queries 11-15
- **Bar Charts**: Queries 16-20
- **Tables**: Queries 21-30
- **Time Series**: Queries 31-33
- **Advanced Analytics**: Queries 34-40

### Alerting Recommendations
Create alerts on:
- Query 34 (Risk Score > threshold)
- Query 36 (Stale policies)
- Query 3 (Exempted users spike)
- Query 38 (Orphaned resources)

---

## 📚 Related Documentation

See also:
- [Module README](../README.md) - Terraform module documentation
- [PowerShell Scripts](../PowerShell/) - Data ingestion scripts
- [Schema Definitions](../infrastructure/azurerm-law-dcr/) - Table schemas

---

**Last Updated**: 2025-01-17
**Version**: 1.0
**Total Queries**: 40
