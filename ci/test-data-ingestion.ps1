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
# Build path that works cross-platform (case-sensitive for Linux)
$repoRoot = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $repoRoot "PowerShell" "modules" "AzMonitorIngestion" "AzMonitorIngestion.psd1"
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

# Connect using Azure CLI (pre-installed on GitHub runners)
Write-Host "Connecting to Azure Monitor..." -ForegroundColor Yellow
try {
    Connect-AzMonitorIngestion -UseAzureCli -ErrorAction Stop
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

Write-Host ""
Write-Host "=== Data Ingestion Test PASSED ===" -ForegroundColor Green
Write-Host "Successfully sent test data to DCR" -ForegroundColor Green
Write-Host ""
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "  - Test ID: $testId" -ForegroundColor Gray
Write-Host "  - DCR: $DcrImmutableId" -ForegroundColor Gray
Write-Host "  - Stream: $StreamName" -ForegroundColor Gray
Write-Host "  - Table: $TableName" -ForegroundColor Gray
exit 0
