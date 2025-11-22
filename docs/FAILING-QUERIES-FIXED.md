# Fixed Versions of Failing Queries

These are API-safe versions of queries #42, #43, #46, #47, #48, #50 that were failing with BadRequest errors.

## Root Causes Fixed:
1. ✅ Null-safe array operations with `coalesce(array, dynamic([]))`
2. ✅ Protected join keys with proper null handling
3. ✅ Empty snapshot protection
4. ✅ Safe dynamic property access
5. ✅ Null-safe set comparisons

---

## Query #42 (FIXED): "Privilege Creep" - Exemptions Added to High-Value Accounts

```kql
// FIXED: Added null safety and empty snapshot protection
let PrivilegedRoleNames = dynamic([
    "Global Administrator",
    "Privileged Role Administrator",
    "Security Administrator",
    "Application Administrator",
    "Cloud Application Administrator",
    "Authentication Administrator",
    "Privileged Authentication Administrator",
    "User Administrator",
    "Exchange Administrator",
    "SharePoint Administrator",
    "Conditional Access Administrator"
]);
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where isnotempty(TimeGenerated)  // Protection against empty results
| summarize
    CurrentTime = arg_max(TimeGenerated, *),
    OldTime = arg_max(iff(TimeGenerated <= ago(7d), TimeGenerated, datetime(null)), *)
    by PolicyId
| where isnotempty(CurrentTime)
| where isnotempty(coalesce(ExcludeRoles, dynamic([])))
| mv-expand CurrentRole = coalesce(ExcludeRoles, dynamic([]))
| extend
    CurrentRoleId = tostring(CurrentRole.Id),
    CurrentRoleName = tostring(CurrentRole.DisplayName),
    OldRolesArray = coalesce(OldTime_ExcludeRoles, dynamic([]))
| where CurrentRoleName in (PrivilegedRoleNames)
| mv-expand OldRole = OldRolesArray to typeof(dynamic)
| summarize OldRoleIds = make_set(tostring(OldRole.Id)) by PolicyId, CurrentRoleId, CurrentRoleName, DisplayName, BuiltInControls, Modified
| where array_length(OldRoleIds) == 0 or CurrentRoleId !has_any (OldRoleIds)
| project
    Alert = "NEW RISK",
    PolicyName = DisplayName,
    PrivilegedRole = CurrentRoleName,
    RoleId = CurrentRoleId,
    PolicyRequirements = BuiltInControls,
    AddedWhen = Modified,
    TimeAgo = format_timespan(now() - Modified, 'd:hh:mm'),
    Severity = case(
        BuiltInControls has "mfa", "CRITICAL - MFA Bypass",
        BuiltInControls has "compliantDevice", "HIGH - Device Compliance Bypass",
        "MEDIUM"
    )
| order by Modified desc
```

---

## Query #43 (FIXED): "Blast Radius Calculator"

```kql
// FIXED: Removed hardcoded variable, added null safety
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

---

## Query #46 (FIXED): "Exemption Velocity Tracker"

```kql
// FIXED: Added empty snapshot protection and null-safe arithmetic
let CurrentData =
    ConditionalAccessPolicies_CL
    | where TimeGenerated {TimeRange}
    | where TimeGenerated > ago(1d)
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend CurrentExemptions = toint(
        coalesce(array_length(ExcludeGroups), 0) +
        coalesce(array_length(ExcludeUsers), 0) +
        coalesce(array_length(ExcludeRoles), 0)
    )
    | project PolicyId, DisplayName, CurrentExemptions, BuiltInControls, ExcludeGroups, ExcludeUsers, Modified;
let PreviousData =
    ConditionalAccessPolicies_CL
    | where TimeGenerated {TimeRange}
    | where TimeGenerated > ago(8d) and TimeGenerated <= ago(7d)
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend PreviousExemptions = toint(
        coalesce(array_length(ExcludeGroups), 0) +
        coalesce(array_length(ExcludeUsers), 0) +
        coalesce(array_length(ExcludeRoles), 0)
    )
    | project PolicyId, PreviousExemptions;
CurrentData
| join kind=leftouter (PreviousData) on PolicyId
| extend PreviousExemptions = toint(coalesce(PreviousExemptions, 0))
| where CurrentExemptions > PreviousExemptions
| extend
    ExemptionsAdded = toint(CurrentExemptions - PreviousExemptions),
    PercentIncrease = round(todouble((CurrentExemptions - PreviousExemptions) * 100.0) / nullif(todouble(PreviousExemptions), 0.0), 1),
    WeeklyVelocity = round(todouble(CurrentExemptions - PreviousExemptions), 1)
| extend ThreatIndicator = case(
    PercentIncrease > 100 and BuiltInControls has "mfa", "CRITICAL - MFA Policy Erosion",
    PercentIncrease > 100, "HIGH - Rapid Policy Weakening",
    PercentIncrease > 50, "MEDIUM - Accelerated Exemptions",
    "LOW - Normal Growth"
)
| project
    ThreatIndicator,
    PolicyName = DisplayName,
    ExemptionsAdded,
    PercentIncrease,
    WeeklyVelocity,
    CurrentTotal = CurrentExemptions,
    PreviousTotal = PreviousExemptions,
    Controls = BuiltInControls,
    CurrentGroups = ExcludeGroups,
    CurrentUsers = ExcludeUsers,
    Modified
| order by PercentIncrease desc
```

---

## Query #47 (FIXED): "Orphaned Identity Apocalypse"

```kql
// FIXED: Safe dynamic property access with null protection
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| summarize arg_max(TimeGenerated, *) by PolicyId
| where isnotempty(coalesce(ExcludeUsers, dynamic([]))) or isnotempty(coalesce(ExcludeGroups, dynamic([])))
| extend AllExemptedIdentities = array_concat(
    coalesce(ExcludeUsers, dynamic([])),
    coalesce(ExcludeGroups, dynamic([]))
)
| where array_length(AllExemptedIdentities) > 0
| mv-expand Identity = AllExemptedIdentities to typeof(dynamic)
| extend
    IdentityId = tostring(coalesce(Identity.Id, "")),
    IdentityName = tostring(coalesce(Identity.DisplayName, "Unknown")),
    HasUPN = isnotempty(tostring(coalesce(Identity.userPrincipalName, "")))
| extend IdentityType = iff(HasUPN, "User", "Group")
| where isnotempty(IdentityId) and IdentityId != "All" and IdentityId != "GuestsOrExternalUsers" and IdentityId != ""
| summarize
    PoliciesAffected = make_set(DisplayName),
    PolicyCount = count()
    by IdentityName, IdentityId, IdentityType
| extend
    CleanupPriority = case(
        PolicyCount > 5, "HIGH - Affects many policies",
        PolicyCount > 2, "MEDIUM",
        "LOW"
    )
| project
    CleanupPriority,
    PotentiallyOrphanedIdentity = IdentityName,
    IdentityId,
    Type = IdentityType,
    AffectsPolicyCount = PolicyCount,
    PoliciesRequiringCleanup = PoliciesAffected
| order by PolicyCount desc
```

---

## Query #48 (FIXED): "Compliance Nightmare Matrix"

```kql
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

---

## Query #50 (FIXED): "Conditional Access Entropy"

```kql
// FIXED: Null-safe hash keys with proper coalescing
let AllPolicies =
    ConditionalAccessPolicies_CL
    | where TimeGenerated {TimeRange}
    | where State == "enabled"
    | summarize arg_max(TimeGenerated, *) by PolicyId
    | extend
        SafeIncludeUsers = coalesce(IncludeUsers, dynamic([])),
        SafeIncludeGroups = coalesce(IncludeGroups, dynamic([])),
        SafeIncludeApps = coalesce(IncludeApps, dynamic([]));
AllPolicies
| extend Key = strcat(
    tostring(coalesce(hash(SafeIncludeUsers), hash(""))), "-",
    tostring(coalesce(hash(SafeIncludeGroups), hash(""))), "-",
    tostring(coalesce(hash(SafeIncludeApps), hash("")))
)
| where isnotempty(Key) and Key != "---"
| join kind=inner (
    AllPolicies
    | extend Key = strcat(
        tostring(coalesce(hash(SafeIncludeUsers), hash(""))), "-",
        tostring(coalesce(hash(SafeIncludeGroups), hash(""))), "-",
        tostring(coalesce(hash(SafeIncludeApps), hash("")))
    )
    | where isnotempty(Key) and Key != "---"
) on Key
| where PolicyId != PolicyId1
| where DisplayName < DisplayName1
| extend
    Controls1Str = tostring(coalesce(BuiltInControls, "")),
    Controls2Str = tostring(coalesce(BuiltInControls1, "")),
    ControlsMatch = (tostring(coalesce(BuiltInControls, "")) == tostring(coalesce(BuiltInControls1, ""))),
    SameTarget = (Key == Key1),
    StateDiffers = (State != State1)
| extend ConflictType = case(
    SameTarget and not(ControlsMatch) and not(StateDiffers), "SAME SCOPE DIFFERENT CONTROLS",
    SameTarget and StateDiffers, "CONFLICTING STATES",
    "Potential Overlap"
)
| where SameTarget and (not(ControlsMatch) or StateDiffers)
| project
    ConflictType,
    Policy1 = DisplayName,
    Policy2 = DisplayName1,
    Policy1State = State,
    Policy2State = State1,
    Controls1 = Controls1Str,
    Controls2 = Controls2Str,
    CommonTarget = iff(SafeIncludeUsers has "All", "All Users", strcat("Groups: ", toint(coalesce(array_length(SafeIncludeGroups), 0))))
| order by ConflictType desc
```

---

## Summary of Fixes

| Query | Key Fixes Applied |
|-------|-------------------|
| #42 | Combined snapshots into single query, used `!has_any` instead of `!in`, added empty protection |
| #43 | Removed hardcoded `let` variable, added explicit `toint()` conversions, used `to typeof(dynamic)` |
| #46 | Split into explicit CTEs, added `toint()` and `todouble()` conversions, null-safe division |
| #47 | Added `to typeof(dynamic)`, protected all property access with `coalesce()` |
| #48 | Wrapped all dynamic arrays with `coalesce()`, added explicit `toint()` conversions |
| #50 | Protected hash inputs with `coalesce()`, used `hash("")` as null fallback, changed delimiter |

All queries now include:
- ✅ Null-safe array operations
- ✅ Explicit type conversions (`toint()`, `todouble()`, `tostring()`)
- ✅ Protected dynamic property access
- ✅ Safe join keys
- ✅ Empty result protection
