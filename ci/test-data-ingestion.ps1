# Test Data Ingestion Script for CI
# This script pushes test data to the custom table and verifies it

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

# Get access token for data ingestion
# Note: Azure session is already established by azure/login action with enable-AzPSSession
Write-Host "Getting access token..." -ForegroundColor Yellow
try {
    $accessToken = (Get-AzAccessToken -ResourceUrl "https://monitor.azure.com" -ErrorAction Stop).Token
    Write-Host "Access token obtained successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to get access token: $_"
    Write-Host "Current Azure context:" -ForegroundColor Yellow
    Get-AzContext | Format-List
    exit 1
}

# Create test data
$testId = [guid]::NewGuid().ToString()
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

$testData = @(
    @{
        TimeGenerated = $timestamp
        TestID = $testId
        TestResult = "Success"
        Duration = 1.23
        Message = "CI test data ingestion successful"
    }
)

$jsonData = $testData | ConvertTo-Json -Depth 10 -AsArray
Write-Host "Test data prepared:" -ForegroundColor Yellow
Write-Host $jsonData

# Build ingestion URL
$ingestionUrl = "$DceEndpoint/dataCollectionRules/$DcrImmutableId/streams/$($StreamName)?api-version=2023-01-01"
Write-Host ""
Write-Host "Ingestion URL: $ingestionUrl" -ForegroundColor Yellow

# Send data to DCR
Write-Host ""
Write-Host "Sending data to Log Analytics..." -ForegroundColor Yellow

$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri $ingestionUrl -Method Post -Headers $headers -Body $jsonData -ErrorAction Stop
    Write-Host "Data sent successfully!" -ForegroundColor Green
    Write-Host "Response: $response"
} catch {
    Write-Error "Failed to send data: $_"
    Write-Error "Response: $($_.Exception.Response)"
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
        $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId (Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $WorkspaceName).CustomerId -Query $query -ErrorAction Stop

        if ($queryResults.Results.Count -gt 0) {
            Write-Host ""
            Write-Host "=== Data Ingestion Test PASSED ===" -ForegroundColor Green
            Write-Host "Found $($queryResults.Results.Count) record(s) in the table"
            Write-Host ""
            Write-Host "Query Results:" -ForegroundColor Green
            $queryResults.Results | Format-Table -AutoSize

            # Export results for GitHub Actions
            $env:CI_TEST_PASSED = "true"
            $env:CI_TEST_RECORD_COUNT = $queryResults.Results.Count

            exit 0
        }
    } catch {
        Write-Host "Query failed or returned no results: $_" -ForegroundColor Yellow
    }
}

Write-Error "=== Data Ingestion Test FAILED ==="
Write-Error "No data found in table after $maxWaitTime seconds"
exit 1
