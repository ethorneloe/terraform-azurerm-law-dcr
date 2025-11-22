# Removed Queries - Require Historical Data

These queries were removed from the main library because they require **7+ days of historical snapshot data** to function properly. They fail with `BadRequest` errors when historical data doesn't exist.

## Why These Queries Fail

All of these queries attempt to compare current snapshots with historical snapshots from 7 days ago using patterns like:

```kql
let CurrentSnapshot = ... | where TimeGenerated > ago(1d) ...;
let PreviousSnapshot = ... | where TimeGenerated > ago(8d) and TimeGenerated <= ago(7d) ...;
CurrentSnapshot | join (PreviousSnapshot) on PolicyId
```

When you don't have 7+ days of data ingested, the `PreviousSnapshot` CTE returns empty results, causing join operations to fail via the API.

## Removed Queries

### Query #42: "Privilege Creep" - Exemptions Added to High-Value Accounts

**Purpose**: Detects privileged role exemptions added in the last 7 days

**Why it fails**: Requires comparing current `ExcludeRoles` with `ExcludeRoles` from 7 days ago

**Historical data needed**: Minimum 7 days of snapshots

**Query**:
```kql
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
| where isnotempty(TimeGenerated)
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

### Query #46: "Exemption Velocity Tracker" - Rapid Exemption Growth

**Purpose**: Detects policies where exemptions are increasing rapidly week-over-week

**Why it fails**: Requires comparing current exemption count with count from 7 days ago

**Historical data needed**: Minimum 8 days of snapshots

**Query**:
```kql
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
    Modified,
    InvestigationNote = "Review recent exemption additions - potential policy erosion or attack"
| order by PercentIncrease desc
```

---

### Query #47: "Orphaned Identity Apocalypse" - Deleted Accounts Still Exempted

**Purpose**: Identifies exempted users/groups that may no longer exist in Entra ID

**Why it fails**: Complex mv-expand with nested dynamic property access causes API parsing issues

**Note**: This query also requires integration with Entra ID user/group data to be fully effective

**Query**:
```kql
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

### Query #50: "Conditional Access Entropy" - Policy Contradiction Detector

**Purpose**: Finds conflicting policies with same targets but different controls

**Why it fails**: Self-join with hash-based keys causes API issues with null handling

**Query**:
```kql
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

## How to Re-Enable These Queries

Once you have **7+ days of Conditional Access policy snapshots** ingested into your Log Analytics workspace:

1. **Copy the queries from this file**
2. **Add them back to the main library** ([CONDITIONAL-ACCESS-KQL-LIBRARY.md](CONDITIONAL-ACCESS-KQL-LIBRARY.md))
3. **Renumber subsequent queries** if needed
4. **Test with the validation script**:
   ```powershell
   .\PowerShell\Test-KQLQueryLibrary.ps1 -WorkspaceName "your-workspace" -ResourceGroupName "your-rg"
   ```

## Alternative: Simplified Non-Historical Versions

If you want the functionality without historical comparison, you can create simplified versions:

### Example: Static Privilege Creep Detector
Instead of comparing snapshots, just show ALL privileged roles currently exempted:

```kql
let PrivilegedRoleNames = dynamic([
    "Global Administrator",
    "Privileged Role Administrator",
    "Security Administrator"
]);
ConditionalAccessPolicies_CL
| where TimeGenerated {TimeRange}
| where State == "enabled"
| summarize arg_max(TimeGenerated, *) by PolicyId
| where isnotempty(ExcludeRoles)
| mv-expand Role = ExcludeRoles
| extend
    RoleName = tostring(Role.DisplayName),
    RoleId = tostring(Role.Id)
| where RoleName in (PrivilegedRoleNames)
| project
    PolicyName = DisplayName,
    PrivilegedRole = RoleName,
    BuiltInControls,
    Modified
| order by Modified desc
```

This version shows the **current state** without requiring historical data for comparison.
