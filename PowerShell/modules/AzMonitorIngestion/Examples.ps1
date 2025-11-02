# Example Usage: Azure Monitor Ingestion Module
# This script demonstrates various ways to use the AzMonitorIngestion module

#region Setup
# Import the module
Import-Module AzMonitorIngestion -Force

# Display module information
Get-AzMonitorModuleInfo

# Configuration (replace with your actual values)
$config = @{
    DceEndpoint     = "https://dce-prod-shared.eastus-1.ingest.monitor.azure.com"
    DcrImmutableId  = "dcr-abc123def456789..."
    StreamName      = "Custom-ComplianceChecks_CL"
    TenantId        = "your-tenant-id"
    ApplicationId   = "your-app-id"
}
#endregion

#region Example 1: Interactive Authentication
Write-Host "`n=== Example 1: Interactive Authentication ===" -ForegroundColor Cyan

# Login interactively
Connect-AzAccount

# Use current context
Connect-AzMonitorIngestion -UseCurrentContext

# Create sample data
$data = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        ServerName    = "WEB-01"
        CheckName     = "TLS1.2Enabled"
        Status        = "PASS"
        Score         = 100
        Details       = "TLS 1.2 is properly configured"
    }
)

# Send data
Send-AzMonitorData `
    -DceEndpoint $config.DceEndpoint `
    -DcrImmutableId $config.DcrImmutableId `
    -StreamName $config.StreamName `
    -Data $data `
    -Verbose
#endregion

#region Example 2: Managed Identity (for Azure VMs)
Write-Host "`n=== Example 2: Managed Identity ===" -ForegroundColor Cyan

# This would run on an Azure VM with system-assigned managed identity
Connect-AzMonitorIngestion -UseManagedIdentity

# Collect system information
$systemData = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        ServerName    = $env:COMPUTERNAME
        CheckName     = "SystemHealth"
        Status        = "PASS"
        Score         = 95
        Details       = "All systems operational"
    }
)

Send-AzMonitorData `
    -DceEndpoint $config.DceEndpoint `
    -DcrImmutableId $config.DcrImmutableId `
    -StreamName $config.StreamName `
    -Data $systemData
#endregion

#region Example 3: Service Principal with Secret
Write-Host "`n=== Example 3: Service Principal with Secret ===" -ForegroundColor Cyan

# Securely get the client secret
$clientSecret = Read-Host "Enter client secret" -AsSecureString

# Authenticate
Connect-AzMonitorIngestion `
    -TenantId $config.TenantId `
    -ApplicationId $config.ApplicationId `
    -ServicePrincipalSecret $clientSecret

# Send data
$spData = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        ServerName    = "APP-01"
        CheckName     = "ServicePrincipalAuth"
        Status        = "PASS"
        Score         = 100
        Details       = "Authenticated successfully"
    }
)

Send-AzMonitorData `
    -DceEndpoint $config.DceEndpoint `
    -DcrImmutableId $config.DcrImmutableId `
    -StreamName $config.StreamName `
    -Data $spData
#endregion

#region Example 4: Large Dataset with Batching
Write-Host "`n=== Example 4: Large Dataset with Batching ===" -ForegroundColor Cyan

# Generate large dataset (simulating 2000 records)
$largeDataset = 1..2000 | ForEach-Object {
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        ServerName    = "WEB-$($_ % 10)"
        CheckName     = "LoadTest"
        Status        = @("PASS", "WARN", "FAIL")[(Get-Random -Maximum 3)]
        Score         = Get-Random -Minimum 50 -Maximum 100
        Details       = "Batch test record $_"
    }
}

Write-Host "Generated $($largeDataset.Count) records"

# Send with custom batch size
$result = Send-AzMonitorData `
    -DceEndpoint $config.DceEndpoint `
    -DcrImmutableId $config.DcrImmutableId `
    -StreamName $config.StreamName `
    -Data $largeDataset `
    -BatchSize 500 `
    -RetryAttempts 3 `
    -Verbose

# Display results
Write-Host "`nIngestion Summary:"
$result | Format-List
#endregion

#region Example 5: Error Handling
Write-Host "`n=== Example 5: Error Handling ===" -ForegroundColor Cyan

# Prepare data
$testData = @(
    [PSCustomObject]@{
        TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
        ServerName    = "TEST-01"
        CheckName     = "ErrorHandlingTest"
        Status        = "PASS"
        Score         = 100
        Details       = "Testing error handling"
    }
)

# Send with comprehensive error handling
try {
    $result = Send-AzMonitorData `
        -DceEndpoint $config.DceEndpoint `
        -DcrImmutableId $config.DcrImmutableId `
        -StreamName $config.StreamName `
        -Data $testData `
        -ErrorAction Stop
    
    if ($result.Success) {
        Write-Host "✓ All records sent successfully!" -ForegroundColor Green
        Write-Host "  Total: $($result.TotalRecords)"
        Write-Host "  Success: $($result.SuccessfulSends)"
        Write-Host "  Failed: $($result.FailedSends)"
    }
    else {
        Write-Warning "Partial failure detected"
        Write-Host "  Successful: $($result.SuccessfulSends)" -ForegroundColor Green
        Write-Host "  Failed: $($result.FailedSends)" -ForegroundColor Red
    }
}
catch {
    Write-Error "Critical failure: $_"
    
    # Provide specific guidance based on error
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        
        switch ($statusCode) {
            401 { 
                Write-Host "→ Action: Re-authenticate with Connect-AzMonitorIngestion" -ForegroundColor Yellow 
            }
            403 { 
                Write-Host "→ Action: Verify 'Monitoring Metrics Publisher' role on DCR" -ForegroundColor Yellow
                Write-Host "→ Command: New-AzRoleAssignment -RoleDefinitionName 'Monitoring Metrics Publisher' -ObjectId <id> -Scope <dcr-id>" -ForegroundColor Yellow
            }
            404 { 
                Write-Host "→ Action: Verify DCR Immutable ID and Stream Name" -ForegroundColor Yellow 
            }
            413 { 
                Write-Host "→ Action: Reduce BatchSize parameter" -ForegroundColor Yellow 
            }
            429 { 
                Write-Host "→ Action: Add -ThrottleOnFailure switch or reduce frequency" -ForegroundColor Yellow 
            }
            default {
                Write-Host "→ HTTP Status Code: $statusCode" -ForegroundColor Yellow
            }
        }
    }
}
#endregion

#region Example 6: Diagnostic Tests
Write-Host "`n=== Example 6: Diagnostic Tests ===" -ForegroundColor Cyan

# Test DCE connectivity
Write-Host "`nTesting DCE connectivity..."
$connectivityTest = Test-AzMonitorIngestion -DceEndpoint $config.DceEndpoint

if ($connectivityTest) {
    Write-Host "✓ DCE is reachable" -ForegroundColor Green
}
else {
    Write-Host "✗ DCE connectivity issues detected" -ForegroundColor Red
}

# Test RBAC permissions (requires DCR resource ID and principal ID)
<#
$dcrResourceId = "/subscriptions/{sub-id}/resourceGroups/rg-monitoring/providers/Microsoft.Insights/dataCollectionRules/dcr-ComplianceChecks_CL"
$principalId = "12345678-1234-1234-1234-123456789012"

Write-Host "`nTesting RBAC permissions..."
$permissionTest = Test-AzMonitorPermissions -DcrResourceId $dcrResourceId -PrincipalId $principalId

if ($permissionTest) {
    Write-Host "✓ Principal has required permissions" -ForegroundColor Green
}
else {
    Write-Host "✗ Missing 'Monitoring Metrics Publisher' role" -ForegroundColor Red
}
#>
#endregion

#region Example 7: Real-World Compliance Checks
Write-Host "`n=== Example 7: Real-World Compliance Checks ===" -ForegroundColor Cyan

function Invoke-ComplianceChecks {
    param(
        [string]$DceEndpoint,
        [string]$DcrId,
        [string]$StreamName
    )
    
    $complianceData = @()
    
    # Check 1: Disk Space
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
        $freePercent = ($_.Free / ($_.Used + $_.Free)) * 100
        $status = switch ($freePercent) {
            { $_ -gt 20 } { "PASS"; break }
            { $_ -gt 10 } { "WARN"; break }
            default { "FAIL" }
        }
        
        $complianceData += [PSCustomObject]@{
            TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
            ServerName    = $env:COMPUTERNAME
            CheckName     = "DiskSpace_$($_.Name)"
            Status        = $status
            Score         = [int]$freePercent
            Details       = "Free: $([math]::Round($_.Free/1GB, 2)) GB / Total: $([math]::Round(($_.Used + $_.Free)/1GB, 2)) GB"
        }
    }
    
    # Check 2: Windows Update Status (Windows only)
    if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) {
        try {
            $lastUpdate = (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn
            $daysSinceUpdate = ((Get-Date) - $lastUpdate).Days
            
            $status = if ($daysSinceUpdate -lt 30) { "PASS" } elseif ($daysSinceUpdate -lt 60) { "WARN" } else { "FAIL" }
            
            $complianceData += [PSCustomObject]@{
                TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
                ServerName    = $env:COMPUTERNAME
                CheckName     = "WindowsUpdateAge"
                Status        = $status
                Score         = [Math]::Max(0, 100 - $daysSinceUpdate)
                Details       = "Last update: $lastUpdate ($daysSinceUpdate days ago)"
            }
        }
        catch {
            Write-Warning "Could not check Windows Update status: $_"
        }
    }
    
    # Check 3: Service Status (example: W32Time on Windows)
    if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) {
        try {
            $service = Get-Service -Name "W32Time" -ErrorAction SilentlyContinue
            if ($service) {
                $status = if ($service.Status -eq 'Running') { "PASS" } else { "FAIL" }
                
                $complianceData += [PSCustomObject]@{
                    TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
                    ServerName    = $env:COMPUTERNAME
                    CheckName     = "TimeService"
                    Status        = $status
                    Score         = if ($status -eq "PASS") { 100 } else { 0 }
                    Details       = "Service status: $($service.Status)"
                }
            }
        }
        catch {
            Write-Warning "Could not check service status: $_"
        }
    }
    
    Write-Host "Collected $($complianceData.Count) compliance checks"
    
    # Send to Log Analytics
    if ($complianceData.Count -gt 0) {
        $result = Send-AzMonitorData `
            -DceEndpoint $DceEndpoint `
            -DcrImmutableId $DcrId `
            -StreamName $StreamName `
            -Data $complianceData `
            -Verbose
        
        return $result
    }
    else {
        Write-Warning "No compliance data collected"
        return $null
    }
}

# Run compliance checks
$complianceResult = Invoke-ComplianceChecks `
    -DceEndpoint $config.DceEndpoint `
    -DcrId $config.DcrImmutableId `
    -StreamName $config.StreamName

if ($complianceResult -and $complianceResult.Success) {
    Write-Host "`n✓ Compliance checks completed and sent successfully!" -ForegroundColor Green
}
#endregion

#region Example 8: Scheduled Task Pattern
Write-Host "`n=== Example 8: Scheduled Task Pattern ===" -ForegroundColor Cyan

# This would be saved as a separate script and scheduled
$scriptBlock = {
    param($DceEndpoint, $DcrId, $StreamName)
    
    # Import module
    Import-Module AzMonitorIngestion
    
    # Authenticate (using system-assigned MI if on Azure VM)
    try {
        Connect-AzMonitorIngestion -UseManagedIdentity -ErrorAction Stop
    }
    catch {
        # Fallback to current context
        Connect-AzMonitorIngestion -UseCurrentContext
    }
    
    # Collect and send data
    $data = @(
        [PSCustomObject]@{
            TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
            ServerName    = $env:COMPUTERNAME
            CheckName     = "ScheduledCheck"
            Status        = "PASS"
            Score         = 100
            Details       = "Scheduled task executed successfully"
        }
    )
    
    Send-AzMonitorData `
        -DceEndpoint $DceEndpoint `
        -DcrImmutableId $DcrId `
        -StreamName $StreamName `
        -Data $data
}

Write-Host "Example script block created (would be scheduled separately)"
#endregion

Write-Host "`n=== Examples Complete ===" -ForegroundColor Green
Write-Host "Review the output above to see different usage patterns."
Write-Host "Modify the `$config variable at the top with your actual Azure resources.`n"
