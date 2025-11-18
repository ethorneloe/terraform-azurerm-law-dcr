# Useful KQL Queries for Exemption Analysis

These queries help you analyze and audit Conditional Access exemptions. Run them directly in Log Analytics to investigate specific scenarios.

## Finding Over-Exempted Entities

### Groups Exempted from Many Policies
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| where isnotempty(ExcludeGroups)
| mv-expand Group = ExcludeGroups
| extend GroupId = tostring(Group.Id), GroupName = tostring(Group.DisplayName)
| where isnotempty(GroupId)
| summarize
    ExemptedFromPolicies = make_list(DisplayName),
    PolicyCount = count()
    by GroupName, GroupId
| where PolicyCount > 3  // Alert if exempted from more than 3 policies
| order by PolicyCount desc
```

### Users Exempted from Multiple Policies
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| where isnotempty(ExcludeUsers)
| mv-expand User = ExcludeUsers
| extend UserId = tostring(User.Id), UserPrincipal = tostring(User.UserPrincipalName)
| where UserPrincipal != 'All' and UserPrincipal != 'GuestsOrExternalUsers'
| summarize
    ExemptedFromPolicies = make_list(DisplayName),
    PolicyCount = count()
    by UserPrincipal
| where PolicyCount > 2  // Alert if exempted from more than 2 policies
| order by PolicyCount desc
```

## MFA Exemption Auditing

### All MFA Policy Exemptions
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| where BuiltInControls has 'mfa' or BuiltInControls has 'multiFactor'
| extend
    ExemptGroupCount = array_length(ExcludeGroups),
    ExemptUserCount = array_length(ExcludeUsers),
    ExemptRoleCount = array_length(ExcludeRoles)
| project
    Policy = DisplayName,
    ExemptedGroups = ExcludeGroups,
    ExemptedUsers = ExcludeUsers,
    ExemptedRoles = ExcludeRoles,
    TotalExemptions = ExemptGroupCount + ExemptUserCount + ExemptRoleCount
| order by TotalExemptions desc
```

### MFA Exemptions for Specific Group
```kql
let TargetGroup = "Break Glass Accounts";  // Change this
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| where BuiltInControls has 'mfa' or BuiltInControls has 'multiFactor'
| where isnotempty(ExcludeGroups)
| mv-expand Group = ExcludeGroups
| extend GroupName = tostring(Group.DisplayName)
| where GroupName == TargetGroup
| project
    Policy = DisplayName,
    GroupExempted = GroupName,
    AllExemptedGroups = ExcludeGroups,
    PolicyScope = IncludeUsers
```

## Exemption Trend Analysis

### Exemption Growth Over Time
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(30d)
| where State == 'enabled'
| extend TotalExemptions = coalesce(array_length(ExcludeGroups), 0)
                         + coalesce(array_length(ExcludeUsers), 0)
                         + coalesce(array_length(ExcludeRoles), 0)
| summarize AvgExemptionsPerPolicy = avg(TotalExemptions) by bin(TimeGenerated, 1d)
| render timechart
```

### Policies with Increasing Exemptions
```kql
let CurrentSnapshot =
    ConditionalAccessPolicies_CL
    | where TimeGenerated > ago(1d)
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend CurrentExemptions = coalesce(array_length(ExcludeGroups), 0) + coalesce(array_length(ExcludeUsers), 0);
let PreviousSnapshot =
    ConditionalAccessPolicies_CL
    | where TimeGenerated > ago(8d) and TimeGenerated <= ago(7d)
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend PreviousExemptions = coalesce(array_length(ExcludeGroups), 0) + coalesce(array_length(ExcludeUsers), 0);
CurrentSnapshot
| join kind=inner (PreviousSnapshot) on PolicyId
| where CurrentExemptions > PreviousExemptions
| project
    Policy = DisplayName,
    ExemptionIncrease = CurrentExemptions - PreviousExemptions,
    CurrentTotal = CurrentExemptions,
    PreviousTotal = PreviousExemptions,
    Modified
| order by ExemptionIncrease desc
```

## Application Exemption Analysis

### Apps Exempted from MFA
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| where BuiltInControls has 'mfa' or BuiltInControls has 'multiFactor'
| where isnotempty(ExcludeApps)
| mv-expand App = ExcludeApps
| extend AppId = tostring(App.Id), AppName = tostring(App.DisplayName)
| summarize
    ExemptedFromPolicies = make_list(DisplayName),
    PolicyCount = count()
    by AppName
| order by PolicyCount desc
```

### Legacy Authentication Apps Still Allowed
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| where ClientAppTypes has 'exchangeActiveSync' or ClientAppTypes has 'other'
| where isnotempty(ExcludeApps)
| project
    Policy = DisplayName,
    LegacyProtocolsAllowed = ClientAppTypes,
    ExemptedApps = ExcludeApps
```

## Compliance and Security Findings

### Policies with "Exemption Sprawl" (>5 exemptions)
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| extend TotalExemptions = coalesce(array_length(ExcludeGroups), 0)
                         + coalesce(array_length(ExcludeUsers), 0)
                         + coalesce(array_length(ExcludeRoles), 0)
                         + coalesce(array_length(ExcludeApps), 0)
| where TotalExemptions > 5
| project
    Policy = DisplayName,
    TotalExemptions,
    Groups = array_length(ExcludeGroups),
    Users = array_length(ExcludeUsers),
    Roles = array_length(ExcludeRoles),
    Apps = array_length(ExcludeApps)
| order by TotalExemptions desc
```

### Privileged Roles with Exemptions (Risky!)
```kql
let PrivilegedRoles = dynamic([
    "Global Administrator",
    "Privileged Role Administrator",
    "Security Administrator",
    "Application Administrator"
]);
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| where isnotempty(ExcludeRoles)
| mv-expand Role = ExcludeRoles
| extend RoleName = tostring(Role.DisplayName)
| where RoleName in (PrivilegedRoles)
| project
    Policy = DisplayName,
    PrivilegedRoleExempted = RoleName,
    RequiredControls = BuiltInControls,
    Severity = "HIGH"
```

### Policies with Guest User Exemptions
```kql
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| where isnotempty(ExcludeGuestsOrExternalUsers)
| project
    Policy = DisplayName,
    GuestExemptions = ExcludeGuestsOrExternalUsers,
    RequiredControls = BuiltInControls
```

## Change Detection

### Exemptions Added in Last 24 Hours
```kql
let Yesterday =
    ConditionalAccessPolicies_CL
    | where TimeGenerated > ago(2d) and TimeGenerated <= ago(1d)
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend YesterdayExemptions = pack('Groups', ExcludeGroups, 'Users', ExcludeUsers, 'Roles', ExcludeRoles);
let Today =
    ConditionalAccessPolicies_CL
    | where TimeGenerated > ago(1d)
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend TodayExemptions = pack('Groups', ExcludeGroups, 'Users', ExcludeUsers, 'Roles', ExcludeRoles);
Today
| join kind=inner (Yesterday) on PolicyId
| where TodayExemptions != YesterdayExemptions
| project
    Policy = DisplayName,
    Modified,
    CurrentGroups = ExcludeGroups,
    CurrentUsers = ExcludeUsers
```

### Exemptions Removed (Hardening)
```kql
let Week1 =
    ConditionalAccessPolicies_CL
    | where TimeGenerated > ago(8d) and TimeGenerated <= ago(7d)
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend Week1Exemptions = coalesce(array_length(ExcludeGroups), 0) + coalesce(array_length(ExcludeUsers), 0);
let Week2 =
    ConditionalAccessPolicies_CL
    | where TimeGenerated > ago(1d)
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend Week2Exemptions = coalesce(array_length(ExcludeGroups), 0) + coalesce(array_length(ExcludeUsers), 0);
Week2
| join kind=inner (Week1) on PolicyId
| where Week2Exemptions < Week1Exemptions
| project
    Policy = DisplayName,
    ExemptionsRemoved = Week1Exemptions - Week2Exemptions,
    NewTotal = Week2Exemptions,
    Status = "Hardened ✓"
| order by ExemptionsRemoved desc
```

## Cross-Policy Analysis

### Find Entities Exempted Across All Policies
```kql
// Groups exempted from ALL enabled policies (effectively bypassing CA entirely)
let EnabledPolicyCount = toscalar(
    ConditionalAccessPolicies_CL
    | where TimeGenerated > ago(7d)
    | where State == 'enabled'
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | summarize count()
);
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| summarize arg_max(TimeGenerated, *) by PolicyId
| where isnotempty(ExcludeGroups)
| mv-expand Group = ExcludeGroups
| extend GroupName = tostring(Group.DisplayName)
| summarize PolicyCount = count() by GroupName
| where PolicyCount == EnabledPolicyCount
| project
    GroupName,
    ExemptedFromAllPolicies = PolicyCount,
    Severity = "CRITICAL"
```

### Compare Exemptions Across Environments (if you have dev/prod)
```kql
// Tag your policies with environment metadata, then:
ConditionalAccessPolicies_CL
| where TimeGenerated > ago(7d)
| where State == 'enabled'
| extend Environment = iff(DisplayName has 'PROD', 'Production', 'Development')
| extend TotalExemptions = coalesce(array_length(ExcludeGroups), 0) + coalesce(array_length(ExcludeUsers), 0)
| summarize
    AvgExemptions = avg(TotalExemptions),
    MaxExemptions = max(TotalExemptions),
    PolicyCount = count()
    by Environment
```

---

## Pro Tips

1. **Save queries as Functions**: In Log Analytics, save commonly used queries as functions for reusability
2. **Create Alerts**: Use these queries to set up Azure Monitor alerts for exemption changes
3. **Export for Compliance**: Export query results to Excel/CSV for audit documentation
4. **Compare Snapshots**: Use time-based comparisons to track exemption drift
5. **Filter by Policy Type**: Add filters for specific grant controls (MFA, compliant device, etc.)

## Alerting Recommendations

Create Azure Monitor alert rules for:
- New exemptions added to MFA policies
- Privileged roles exempted from any policy
- Groups exempted from more than 3 policies
- Total exemption count increasing by >20% week-over-week
