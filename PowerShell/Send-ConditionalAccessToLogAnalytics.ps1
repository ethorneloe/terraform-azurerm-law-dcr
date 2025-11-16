<#
.SYNOPSIS
    Collects Conditional Access policy configuration and sends it to Log Analytics.

.DESCRIPTION
    This script retrieves Conditional Access policies from Entra ID using the
    Get-ConditionalAccessConfiguration function and ingests the data into a
    Log Analytics custom table via Data Collection Rules (DCR).

    Designed to run as an Azure Automation runbook or scheduled task for
    continuous monitoring of Conditional Access policy changes.

.PARAMETER DceEndpoint
    The Data Collection Endpoint URL for log ingestion.
    Example: https://dce-prod-001.australiaeast-1.ingest.monitor.azure.com

.PARAMETER DcrImmutableId
    The immutable ID (GUID) of the Data Collection Rule.
    Example: dcr-1234567890abcdef1234567890abcdef

.PARAMETER PoliciesStreamName
    The stream name for the Policies DCR (typically "Custom-ConditionalAccessPolicies_CL").
    Example: Custom-ConditionalAccessPolicies_CL

.PARAMETER PoliciesDcrImmutableId
    The immutable ID (GUID) of the Data Collection Rule for Policies.
    Example: dcr-1234567890abcdef1234567890abcdef

.PARAMETER NamedLocationsStreamName
    The stream name for the Named Locations DCR (typically "Custom-ConditionalAccessNamedLocations_CL").
    Example: Custom-ConditionalAccessNamedLocations_CL

.PARAMETER NamedLocationsDcrImmutableId
    The immutable ID (GUID) of the Data Collection Rule for Named Locations.
    Example: dcr-abcdef1234567890abcdef1234567890

.PARAMETER TenantId
    The Entra ID tenant ID to query.
    If not specified, uses the current context.

.PARAMETER UseExistingGraphSession
    Switch to reuse an existing Microsoft Graph session instead of connecting.

.PARAMETER UseManagedIdentity
    Switch to authenticate to Azure Monitor using managed identity.
    Use this when running in Azure Automation or on an Azure VM.

.PARAMETER UseCurrentContext
    Switch to authenticate to Azure Monitor using the current Azure PowerShell context.

.PARAMETER UseAzureCli
    Switch to authenticate to Azure Monitor using Azure CLI credentials.

.EXAMPLE
    # Run in Azure Automation with Managed Identity
    .\Send-ConditionalAccessToLogAnalytics.ps1 `
        -DceEndpoint "https://dce-prod-001.australiaeast-1.ingest.monitor.azure.com" `
        -PoliciesDcrImmutableId "dcr-abc123..." `
        -PoliciesStreamName "Custom-ConditionalAccessPolicies_CL" `
        -NamedLocationsDcrImmutableId "dcr-def456..." `
        -NamedLocationsStreamName "Custom-ConditionalAccessNamedLocations_CL" `
        -UseManagedIdentity

.EXAMPLE
    # Run locally with existing sessions
    Connect-MgGraph -Scopes "Policy.Read.All"
    Connect-AzAccount
    .\Send-ConditionalAccessToLogAnalytics.ps1 `
        -DceEndpoint "https://dce-dev-001.australiaeast-1.ingest.monitor.azure.com" `
        -PoliciesDcrImmutableId "dcr-policies123..." `
        -PoliciesStreamName "Custom-ConditionalAccessPolicies_CL" `
        -NamedLocationsDcrImmutableId "dcr-locations456..." `
        -NamedLocationsStreamName "Custom-ConditionalAccessNamedLocations_CL" `
        -UseExistingGraphSession `
        -UseCurrentContext

.NOTES
    Author: Generated for terraform-azurerm-law-dcr
    Requires:
    - EntraAutomation module (for Get-ConditionalAccessConfiguration)
    - AzMonitorIngestion module (from this repository)
    - Microsoft Graph PowerShell SDK
    - Appropriate Graph API permissions: Policy.Read.All
    - Azure Monitor permissions: Monitoring Metrics Publisher on the DCR
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DceEndpoint,

    [Parameter(Mandatory = $true)]
    [string]$PoliciesDcrImmutableId,

    [Parameter(Mandatory = $true)]
    [string]$PoliciesStreamName,

    [Parameter(Mandatory = $true)]
    [string]$NamedLocationsDcrImmutableId,

    [Parameter(Mandatory = $true)]
    [string]$NamedLocationsStreamName,

    [Parameter(Mandatory = $false)]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [switch]$UseExistingGraphSession,

    [Parameter(Mandatory = $false, ParameterSetName = 'ManagedIdentity')]
    [switch]$UseManagedIdentity,

    [Parameter(Mandatory = $false, ParameterSetName = 'CurrentContext')]
    [switch]$UseCurrentContext,

    [Parameter(Mandatory = $false, ParameterSetName = 'AzureCli')]
    [switch]$UseAzureCli
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Conditional Access to Log Analytics Ingestion ===" -ForegroundColor Cyan
Write-Host ""

#region Import Required Modules

Write-Host "Importing required modules..." -ForegroundColor Yellow

# Import AzMonitorIngestion module from this repository
$azMonitorModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "PowerShell" "modules" "AzMonitorIngestion" "AzMonitorIngestion.psm1"
if (-not (Test-Path $azMonitorModulePath)) {
    Write-Error "AzMonitorIngestion module not found at: $azMonitorModulePath"
    exit 1
}
Import-Module $azMonitorModulePath -Force
Write-Host "✓ AzMonitorIngestion module imported" -ForegroundColor Green

# Check for EntraAutomation module (contains Get-ConditionalAccessConfiguration)
if (-not (Get-Module -ListAvailable -Name EntraAutomation)) {
    Write-Error "EntraAutomation module not found. Install it with: Install-Module -Name EntraAutomation"
    exit 1
}
Import-Module EntraAutomation -Force
Write-Host "✓ EntraAutomation module imported" -ForegroundColor Green

Write-Host ""

#endregion

#region Connect to Microsoft Graph

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow

if (-not $UseExistingGraphSession) {
    $graphParams = @{
        Scopes = @('Policy.Read.All', 'Directory.Read.All')
    }

    if ($TenantId) {
        $graphParams['TenantId'] = $TenantId
    }

    # If running in Azure Automation with managed identity
    if ($UseManagedIdentity) {
        $graphParams['Identity'] = $true
    }

    try {
        Connect-MgGraph @graphParams -ErrorAction Stop
        Write-Host "✓ Connected to Microsoft Graph" -ForegroundColor Green
    } catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        exit 1
    }
} else {
    Write-Host "✓ Using existing Microsoft Graph session" -ForegroundColor Green
}

# Verify Graph connection
$context = Get-MgContext
Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor Gray
Write-Host "  Account: $($context.Account)" -ForegroundColor Gray
Write-Host ""

#endregion

#region Connect to Azure Monitor

Write-Host "Connecting to Azure Monitor..." -ForegroundColor Yellow

try {
    if ($UseManagedIdentity) {
        Connect-AzMonitorIngestion -UseManagedIdentity -ErrorAction Stop
    } elseif ($UseCurrentContext) {
        Connect-AzMonitorIngestion -UseCurrentContext -ErrorAction Stop
    } elseif ($UseAzureCli) {
        Connect-AzMonitorIngestion -UseAzureCli -ErrorAction Stop
    } else {
        Write-Error "You must specify one of: -UseManagedIdentity, -UseCurrentContext, or -UseAzureCli"
        exit 1
    }
    Write-Host "✓ Connected to Azure Monitor" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Azure Monitor: $_"
    exit 1
}

Write-Host ""

#endregion

#region Retrieve Conditional Access Configuration

Write-Host "Retrieving Conditional Access configuration..." -ForegroundColor Yellow

try {
    $caConfig = Get-ConditionalAccessConfiguration -UseExistingGraphSession -ErrorAction Stop

    $policyCount = $caConfig.Policies.Count
    $locationCount = $caConfig.NamedLocations.Count

    Write-Host "✓ Retrieved $policyCount Conditional Access policies" -ForegroundColor Green
    Write-Host "✓ Retrieved $locationCount named locations" -ForegroundColor Green
} catch {
    Write-Error "Failed to retrieve Conditional Access configuration: $_"
    exit 1
}

if ($policyCount -eq 0) {
    Write-Warning "No Conditional Access policies found. Nothing to ingest."
    exit 0
}

Write-Host ""

#endregion

#region Transform Data for Log Analytics

Write-Host "Transforming policy data for Log Analytics..." -ForegroundColor Yellow

# Add TimeGenerated timestamp to each policy record
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

$logData = @()

foreach ($policy in $caConfig.Policies) {
    # Create a new object with all properties from the policy plus TimeGenerated
    $logRecord = [PSCustomObject]@{
        TimeGenerated = $timestamp

        # Copy all existing properties from the policy object
        DisplayName                                 = $policy.DisplayName
        PolicyId                                    = $policy.PolicyId
        State                                       = $policy.State
        Created                                     = $policy.Created
        Modified                                    = $policy.Modified

        # Applications
        IncludeApps                                 = $policy.IncludeApps
        ExcludeApps                                 = $policy.ExcludeApps
        IncludeUserActions                          = $policy.IncludeUserActions
        ApplicationFilter                           = $policy.ApplicationFilter

        # Authentication
        AuthenticationFlows                         = $policy.AuthenticationFlows

        # Service Principals
        ExcludeServicePrincipals                    = $policy.ExcludeServicePrincipals
        IncludeServicePrincipals                    = $policy.IncludeServicePrincipals
        ServicePrincipalFilterMode                  = $policy.ServicePrincipalFilterMode
        ServicePrincipalFilterRule                  = $policy.ServicePrincipalFilterRule

        # Client Apps
        ClientAppTypes                              = $policy.ClientAppTypes

        # Devices
        DeviceFilterMode                            = $policy.DeviceFilterMode
        DeviceFilterRule                            = $policy.DeviceFilterRule

        # Locations
        IncludeLocations                            = $policy.IncludeLocations
        ExcludeLocations                            = $policy.ExcludeLocations

        # Platforms
        IncludePlatforms                            = $policy.IncludePlatforms
        ExcludePlatforms                            = $policy.ExcludePlatforms

        # Risk Levels
        UserRiskLevels                              = $policy.UserRiskLevels
        SignInRiskLevels                            = $policy.SignInRiskLevels
        InsiderRiskLevels                           = $policy.InsiderRiskLevels

        # Users, Groups, Roles
        IncludeUsers                                = $policy.IncludeUsers
        ExcludeUsers                                = $policy.ExcludeUsers
        IncludeGroups                               = $policy.IncludeGroups
        ExcludeGroups                               = $policy.ExcludeGroups
        IncludeRoles                                = $policy.IncludeRoles
        ExcludeRoles                                = $policy.ExcludeRoles

        # Guest/External Users
        IncludeGuestsOrExternalUsers                = $policy.IncludeGuestsOrExternalUsers
        ExcludeGuestsOrExternalUsers                = $policy.ExcludeGuestsOrExternalUsers
        IncludeExternalTenantsMembershipKind        = $policy.IncludeExternalTenantsMembershipKind
        IncludeExternalTenantsMembers               = $policy.IncludeExternalTenantsMembers
        ExcludeExternalTenantsMembershipKind        = $policy.ExcludeExternalTenantsMembershipKind
        ExcludeExternalTenantsMembers               = $policy.ExcludeExternalTenantsMembers

        # Grant Controls
        BuiltInControls                             = $policy.BuiltInControls
        CustomAuthenticationFactors                 = $policy.CustomAuthenticationFactors
        TermsOfUse                                  = $policy.TermsOfUse
        Operator                                    = $policy.Operator
        AuthenticationStrengthId                    = $policy.AuthenticationStrengthId
        AuthenticationStrengthDisplayName           = $policy.AuthenticationStrengthDisplayName
        AuthenticationStrengthPolicyType            = $policy.AuthenticationStrengthPolicyType
        AuthenticationStrengthAllowedCombinations   = $policy.AuthenticationStrengthAllowedCombinations
        AuthenticationStrengthRequirementsSatisfied = $policy.AuthenticationStrengthRequirementsSatisfied

        # Session Controls
        ApplicationEnforcedRestrictionsIsEnabled    = $policy.ApplicationEnforcedRestrictionsIsEnabled
        CloudAppSecurityType                        = $policy.CloudAppSecurityType
        CloudAppSecurityIsEnabled                   = $policy.CloudAppSecurityIsEnabled
        DisableResilienceDefaults                   = $policy.DisableResilienceDefaults
        PersistentBrowserIsEnabled                  = $policy.PersistentBrowserIsEnabled
        PersistentBrowserMode                       = $policy.PersistentBrowserMode
        SignInFrequencyAuthenticationType           = $policy.SignInFrequencyAuthenticationType
        SignInFrequencyInterval                     = $policy.SignInFrequencyInterval
        SignInFrequencyIsEnabled                    = $policy.SignInFrequencyIsEnabled
        SignInFrequencyType                         = $policy.SignInFrequencyType
        SignInFrequencyValue                        = $policy.SignInFrequencyValue
    }

    $logData += $logRecord
}

Write-Host "✓ Prepared $($logData.Count) policy records for ingestion" -ForegroundColor Green
Write-Host ""

#endregion

#region Transform Named Locations for Log Analytics

Write-Host "Transforming named locations data for Log Analytics..." -ForegroundColor Yellow

$namedLocationsData = @()

foreach ($location in $caConfig.NamedLocations) {
    # Create a new object with all properties from the location plus TimeGenerated
    $locationRecord = [PSCustomObject]@{
        TimeGenerated                       = $timestamp
        Id                                  = $location.Id
        DisplayName                         = $location.DisplayName
        CreatedDateTime                     = $location.CreatedDateTime
        ModifiedDateTime                    = $location.ModifiedDateTime
        IsTrusted                           = $location.IsTrusted
        IpRanges                            = $location.IpRanges
        Countries                           = $location.Countries
        IncludeUnknownCountriesAndRegions   = $location.IncludeUnknownCountriesAndRegions
        CountryLookupMethod                 = $location.CountryLookupMethod
    }

    $namedLocationsData += $locationRecord
}

Write-Host "✓ Prepared $($namedLocationsData.Count) named location records for ingestion" -ForegroundColor Green
Write-Host ""

#endregion

#region Send Policies Data to Log Analytics

Write-Host "Sending Conditional Access Policies to Log Analytics..." -ForegroundColor Yellow
Write-Host "  DCE: $DceEndpoint" -ForegroundColor Gray
Write-Host "  DCR: $PoliciesDcrImmutableId" -ForegroundColor Gray
Write-Host "  Stream: $PoliciesStreamName" -ForegroundColor Gray
Write-Host ""

try {
    $result = Send-AzMonitorData `
        -DceEndpoint $DceEndpoint `
        -DcrImmutableId $PoliciesDcrImmutableId `
        -StreamName $PoliciesStreamName `
        -Data $logData `
        -Verbose `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "✓ Sent $($logData.Count) Conditional Access policy records" -ForegroundColor Green

} catch {
    Write-Error "Failed to send policies data to Log Analytics: $_"
    exit 1
}

#endregion

#region Send Named Locations Data to Log Analytics

Write-Host ""
Write-Host "Sending Named Locations to Log Analytics..." -ForegroundColor Yellow
Write-Host "  DCE: $DceEndpoint" -ForegroundColor Gray
Write-Host "  DCR: $NamedLocationsDcrImmutableId" -ForegroundColor Gray
Write-Host "  Stream: $NamedLocationsStreamName" -ForegroundColor Gray
Write-Host ""

try {
    $result = Send-AzMonitorData `
        -DceEndpoint $DceEndpoint `
        -DcrImmutableId $NamedLocationsDcrImmutableId `
        -StreamName $NamedLocationsStreamName `
        -Data $namedLocationsData `
        -Verbose `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "✓ Sent $($namedLocationsData.Count) Named Location records" -ForegroundColor Green

} catch {
    Write-Error "Failed to send named locations data to Log Analytics: $_"
    exit 1
}

#endregion

#region Summary

Write-Host ""
Write-Host "=== Ingestion Successful ===" -ForegroundColor Green
Write-Host "✓ Sent $($logData.Count) Conditional Access policy records" -ForegroundColor Green
Write-Host "✓ Sent $($namedLocationsData.Count) Named Location records" -ForegroundColor Green
Write-Host ""
Write-Host "Data will be available for querying in 1-5 minutes." -ForegroundColor Yellow
Write-Host ""
Write-Host "Query examples:" -ForegroundColor Cyan
Write-Host "  // Policies" -ForegroundColor White
Write-Host "  ConditionalAccessPolicies_CL" -ForegroundColor White
Write-Host "  | where TimeGenerated > ago(1h)" -ForegroundColor White
Write-Host "  | project TimeGenerated, DisplayName, State, PolicyId" -ForegroundColor White
Write-Host ""
Write-Host "  // Named Locations" -ForegroundColor White
Write-Host "  ConditionalAccessNamedLocations_CL" -ForegroundColor White
Write-Host "  | where TimeGenerated > ago(1h)" -ForegroundColor White
Write-Host "  | project TimeGenerated, DisplayName, IsTrusted, IpRanges, Countries" -ForegroundColor White

#endregion

Write-Host ""
Write-Host "Script completed successfully." -ForegroundColor Green
