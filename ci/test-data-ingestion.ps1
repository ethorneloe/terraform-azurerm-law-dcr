# Test Data Ingestion Script for CI
# Uses the AzMonitorIngestion module from the powershell/ folder

param(
    [Parameter(Mandatory=$true)]
    [string]$DcrImmutableId,

    [Parameter(Mandatory=$true)]
    [string]$StreamName,

    [Parameter(Mandatory=$true)]
    [string]$DceEndpoint,

    [Parameter(Mandatory=$true)]
    [string]$TableName,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup
)

Write-Host "=== Starting Data Ingestion Test ===" -ForegroundColor Cyan
Write-Host "DCR Immutable ID: $DcrImmutableId"
Write-Host "Stream Name: $StreamName"
Write-Host "DCE Endpoint: $DceEndpoint"
Write-Host "Table Name: $TableName"
Write-Host ""

# Import the AzMonitorIngestion module
# Build path that works cross-platform (Linux runner uses forward slashes)
$repoRoot = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $repoRoot "powershell" "modules" "AzMonitorIngestion" "AzMonitorIngestion.psm1"
Write-Host "Repository root: $repoRoot" -ForegroundColor Cyan
Write-Host "Module path: $modulePath" -ForegroundColor Cyan

if (-not (Test-Path $modulePath)) {
    Write-Error "Module not found at: $modulePath"
    Write-Host "Contents of repository root:" -ForegroundColor Yellow
    Get-ChildItem $repoRoot | Format-Table Name, PSIsContainer
    exit 1
}

Import-Module $modulePath -Force -ErrorAction Stop
Write-Host "Module imported successfully" -ForegroundColor Green
Write-Host ""

# Connect using current Azure context (already authenticated by azure/login action)
Write-Host "Connecting to Azure Monitor..." -ForegroundColor Yellow
try {
    Connect-AzMonitorIngestion -UseCurrentContext -ErrorAction Stop
} catch {
    Write-Error "Failed to connect: $_"
    Write-Host "Current Azure context:" -ForegroundColor Yellow
    Get-AzContext | Format-List
    exit 1
}

# Create test data
$testId = [guid]::NewGuid().ToString()
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

$testData = @(
    [PSCustomObject]@{
        TimeGenerated = $timestamp
        TestID = $testId
        TestResult = "Success"
        Duration = 1.23
        Message = "CI test data ingestion successful"
    }
)

Write-Host "Test data prepared:" -ForegroundColor Yellow
$testData | Format-Table -AutoSize
Write-Host ""

# Send data using the module
Write-Host "Sending data to Azure Monitor..." -ForegroundColor Yellow
try {
    $result = Send-AzMonitorData `
        -DceEndpoint $DceEndpoint `
        -DcrImmutableId $DcrImmutableId `
        -StreamName $StreamName `
        -Data $testData `
        -Verbose `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "Send operation complete:" -ForegroundColor Green
    $result | Format-List
} catch {
    Write-Error "Failed to send data: $_"
    exit 1
}

# Wait for data to be ingested (can take 1-5 minutes)
Write-Host ""
Write-Host "Waiting for data to be ingested (this can take 1-5 minutes)..." -ForegroundColor Yellow
$maxWaitTime = 300 # 5 minutes
$waitInterval = 15 # seconds
$elapsedTime = 0

while ($elapsedTime -lt $maxWaitTime) {
    Start-Sleep -Seconds $waitInterval
    $elapsedTime += $waitInterval

    Write-Host "Checking for data... ($elapsedTime seconds elapsed)" -ForegroundColor Cyan

    # Query the table
    $query = "$TableName | where TestID == '$testId' | project TimeGenerated, TestID, TestResult, Duration, Message"

    try {
        $queryResults = Invoke-AzOperationalInsightsQuery `
            -WorkspaceId (Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $WorkspaceName).CustomerId `
            -Query $query `
            -ErrorAction Stop

        if ($queryResults.Results.Count -gt 0) {
            Write-Host ""
            Write-Host "=== Data Ingestion Test PASSED ===" -ForegroundColor Green
            Write-Host "Found $($queryResults.Results.Count) record(s) in the table"
            Write-Host ""
            Write-Host "Query Results:" -ForegroundColor Green
            $queryResults.Results | Format-Table -AutoSize

            exit 0
        }
    } catch {
        Write-Host "Query failed or returned no results: $_" -ForegroundColor Yellow
    }
}

Write-Error "=== Data Ingestion Test FAILED ==="
Write-Error "No data found in table after $maxWaitTime seconds"
exit 1
