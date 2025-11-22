<#
.SYNOPSIS
    Tests all KQL queries from the Conditional Access KQL Library against a Log Analytics Workspace.

.DESCRIPTION
    This script extracts and tests all 50 KQL queries from the CONDITIONAL-ACCESS-KQL-LIBRARY.md file.
    It validates syntax, executes each query, and reports results including errors and record counts.

.PARAMETER WorkspaceName
    Name of the Log Analytics Workspace to test against.

.PARAMETER ResourceGroupName
    Resource Group containing the Log Analytics Workspace.

.PARAMETER TimeRange
    Time range for queries (default: ago(7d)). Examples: ago(1d), ago(30d)

.PARAMETER OutputFormat
    Output format: Console, JSON, or HTML (default: Console)

.PARAMETER SkipEmptyResults
    Skip queries that return no results (useful for workspaces with no data yet)

.EXAMPLE
    .\Test-KQLQueryLibrary.ps1 -WorkspaceName "my-law" -ResourceGroupName "my-rg"

.EXAMPLE
    .\Test-KQLQueryLibrary.ps1 -WorkspaceName "my-law" -ResourceGroupName "my-rg" -TimeRange "ago(1d)" -OutputFormat JSON

.NOTES
    Requires: Az.OperationalInsights module
    Author: Generated for Conditional Access Monitoring
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$TimeRange = "ago(7d)",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "JSON", "HTML", "CSV")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [switch]$SkipEmptyResults
)

#Requires -Modules Az.OperationalInsights

# Color functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success { param([string]$Message) Write-ColorOutput "✓ $Message" "Green" }
function Write-Failure { param([string]$Message) Write-ColorOutput "✗ $Message" "Red" }
function Write-Warning { param([string]$Message) Write-ColorOutput "⚠ $Message" "Yellow" }
function Write-Info { param([string]$Message) Write-ColorOutput "ℹ $Message" "Cyan" }

# Extract queries from markdown file
function Get-KQLQueriesFromMarkdown {
    param([string]$FilePath)

    $content = Get-Content -Path $FilePath -Raw
    $queries = @()

    # Regex to extract query blocks with their titles
    # Pattern handles Windows line endings (\r\n) and multi-line query content
    $pattern = '###\s+(\d+)\.\s+(.+?)\s*\r?\n```kql\s*\r?\n([\s\S]+?)\r?\n```'
    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

    foreach ($match in $matches) {
        $queries += [PSCustomObject]@{
            Number      = $match.Groups[1].Value
            Title       = $match.Groups[2].Value.Trim()
            Query       = $match.Groups[3].Value.Trim()
            Category    = switch ($match.Groups[1].Value) {
                { $_ -in 1..10 } { "Single Stat" }
                { $_ -in 11..15 } { "Pie Chart" }
                { $_ -in 16..20 } { "Bar Chart" }
                { $_ -in 21..30 } { "Table" }
                { $_ -in 31..33 } { "Time Series" }
                { $_ -in 34..40 } { "Advanced Analytics" }
                { $_ -in 41..50 } { "Critical Security Insights" }
                default { "Unknown" }
            }
        }
    }

    return $queries
}

# Test a single query
function Test-KQLQuery {
    param(
        [PSCustomObject]$QueryInfo,
        [string]$WorkspaceId,
        [string]$TimeRangeValue
    )

    $result = [PSCustomObject]@{
        Number       = $QueryInfo.Number
        Title        = $QueryInfo.Title
        Category     = $QueryInfo.Category
        Status       = "Unknown"
        RecordCount  = 0
        ExecutionTimeMs = 0
        Error        = $null
        HasResults   = $false
    }

    try {
        # Replace {TimeRange} placeholder with proper syntax
        # Queries use "where TimeGenerated {TimeRange}" expecting it to become "where TimeGenerated > ago(7d)"
        $queryText = $QueryInfo.Query -replace '\{TimeRange\}', "> $TimeRangeValue"

        # Measure execution time
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Execute query
        $queryResult = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $queryText -ErrorAction Stop

        $stopwatch.Stop()

        $result.Status = "Success"
        $result.RecordCount = if ($queryResult.Results) { $queryResult.Results.Count } else { 0 }
        $result.ExecutionTimeMs = $stopwatch.ElapsedMilliseconds
        $result.HasResults = ($result.RecordCount -gt 0)

    } catch {
        $result.Status = "Failed"
        $result.Error = $_.Exception.Message
    }

    return $result
}

# Main execution
function Main {
    Write-ColorOutput "`n╔════════════════════════════════════════════════════════════════════╗" "Cyan"
    Write-ColorOutput "║     Conditional Access KQL Query Library Testing Tool             ║" "Cyan"
    Write-ColorOutput "╚════════════════════════════════════════════════════════════════════╝`n" "Cyan"

    # Check for required module
    Write-Info "Checking for Az.OperationalInsights module..."
    if (-not (Get-Module -ListAvailable -Name Az.OperationalInsights)) {
        Write-Failure "Az.OperationalInsights module not found. Install with: Install-Module -Name Az.OperationalInsights"
        return
    }

    # Get workspace
    Write-Info "Connecting to Log Analytics Workspace: $WorkspaceName..."
    try {
        $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction Stop
        $workspaceId = $workspace.CustomerId
        Write-Success "Connected to workspace: $($workspace.Name) (ID: $workspaceId)"
    } catch {
        Write-Failure "Failed to connect to workspace: $_"
        return
    }

    # Find markdown file
    if ($PSScriptRoot) {
        $scriptDir = $PSScriptRoot
    } elseif ($PSCommandPath) {
        $scriptDir = Split-Path -Parent $PSCommandPath
    } else {
        # Running interactively, use current directory
        $scriptDir = Get-Location
    }

    $repoRoot = Split-Path -Parent $scriptDir
    $markdownPath = Join-Path $repoRoot "docs\CONDITIONAL-ACCESS-KQL-LIBRARY.md"

    if (-not (Test-Path $markdownPath)) {
        Write-Failure "KQL Library file not found at: $markdownPath"
        Write-Warning "Expected location: $markdownPath"
        Write-Warning "Script directory: $scriptDir"
        Write-Warning "Repo root: $repoRoot"
        return
    }

    Write-Info "Loading queries from: $markdownPath"
    $queries = Get-KQLQueriesFromMarkdown -FilePath $markdownPath

    if ($queries.Count -eq 0) {
        Write-Failure "No queries found in markdown file"
        return
    }

    Write-Success "Found $($queries.Count) queries to test"
    Write-Info "Time range: $TimeRange`n"

    # Test all queries
    $results = @()
    $successCount = 0
    $failCount = 0
    $emptyCount = 0

    foreach ($query in $queries) {
        Write-Host "Testing Query #$($query.Number): " -NoNewline
        Write-Host "$($query.Title)" -ForegroundColor White

        $result = Test-KQLQuery -QueryInfo $query -WorkspaceId $workspaceId -TimeRangeValue $TimeRange
        $results += $result

        if ($result.Status -eq "Success") {
            if ($result.HasResults) {
                Write-Success "  Status: SUCCESS | Records: $($result.RecordCount) | Time: $($result.ExecutionTimeMs)ms"
                $successCount++
            } else {
                Write-Warning "  Status: SUCCESS (No Results) | Time: $($result.ExecutionTimeMs)ms"
                $emptyCount++
            }
        } else {
            Write-Failure "  Status: FAILED | Error: $($result.Error)"
            $failCount++
        }
    }

    # Summary
    Write-ColorOutput "`n╔════════════════════════════════════════════════════════════════════╗" "Cyan"
    Write-ColorOutput "║                         TEST SUMMARY                                ║" "Cyan"
    Write-ColorOutput "╚════════════════════════════════════════════════════════════════════╝`n" "Cyan"

    $totalTests = $results.Count
    $successRate = [math]::Round(($successCount / $totalTests) * 100, 1)

    Write-Host "Total Queries Tested:  " -NoNewline; Write-ColorOutput "$totalTests" "White"
    Write-Host "Successful (with data): " -NoNewline; Write-ColorOutput "$successCount" "Green"
    Write-Host "Successful (no data):   " -NoNewline; Write-ColorOutput "$emptyCount" "Yellow"
    Write-Host "Failed:                 " -NoNewline; Write-ColorOutput "$failCount" "Red"
    Write-Host "Success Rate:           " -NoNewline; Write-ColorOutput "$successRate%" $(if ($successRate -ge 95) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })

    # Category breakdown
    Write-ColorOutput "`n--- Results by Category ---`n" "Cyan"
    $results | Group-Object Category | ForEach-Object {
        $categorySuccess = ($_.Group | Where-Object { $_.Status -eq "Success" }).Count
        $categoryTotal = $_.Count
        Write-Host "$($_.Name): " -NoNewline
        Write-ColorOutput "$categorySuccess/$categoryTotal passed" $(if ($categorySuccess -eq $categoryTotal) { "Green" } else { "Yellow" })
    }

    # Failed queries detail
    if ($failCount -gt 0) {
        Write-ColorOutput "`n--- Failed Queries ---`n" "Red"
        $results | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
            Write-ColorOutput "Query #$($_.Number): $($_.Title)" "Red"
            Write-ColorOutput "  Error: $($_.Error)`n" "DarkRed"
        }
    }

    # Empty results (if not skipped)
    if (-not $SkipEmptyResults -and $emptyCount -gt 0) {
        Write-ColorOutput "`n--- Queries with No Results (May need data ingestion) ---`n" "Yellow"
        $results | Where-Object { $_.Status -eq "Success" -and -not $_.HasResults } | ForEach-Object {
            Write-ColorOutput "  #$($_.Number): $($_.Title)" "Yellow"
        }
    }

    # Output to file if requested
    if ($OutputFormat -ne "Console") {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $outputFile = Join-Path $scriptDir "query-test-results-$timestamp"

        switch ($OutputFormat) {
            "JSON" {
                $outputFile += ".json"
                $results | ConvertTo-Json -Depth 10 | Out-File $outputFile
                Write-Success "`nResults exported to: $outputFile"
            }
            "CSV" {
                $outputFile += ".csv"
                $results | Export-Csv -Path $outputFile -NoTypeInformation
                Write-Success "`nResults exported to: $outputFile"
            }
            "HTML" {
                $outputFile += ".html"
                $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>KQL Query Test Results</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        h1 { color: #0078d4; }
        table { border-collapse: collapse; width: 100%; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        .success { color: green; font-weight: bold; }
        .failed { color: red; font-weight: bold; }
        .warning { color: orange; }
        .summary { background: white; padding: 20px; margin-bottom: 20px; border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    </style>
</head>
<body>
    <h1>Conditional Access KQL Query Test Results</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Workspace:</strong> $WorkspaceName</p>
        <p><strong>Time Range:</strong> $TimeRange</p>
        <p><strong>Test Date:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        <p><strong>Total Queries:</strong> $totalTests</p>
        <p><strong>Passed (with data):</strong> <span class="success">$successCount</span></p>
        <p><strong>Passed (no data):</strong> <span class="warning">$emptyCount</span></p>
        <p><strong>Failed:</strong> <span class="failed">$failCount</span></p>
        <p><strong>Success Rate:</strong> $successRate%</p>
    </div>
    <h2>Detailed Results</h2>
    <table>
        <thead>
            <tr>
                <th>#</th>
                <th>Query Title</th>
                <th>Category</th>
                <th>Status</th>
                <th>Records</th>
                <th>Time (ms)</th>
                <th>Error</th>
            </tr>
        </thead>
        <tbody>
"@
                foreach ($r in $results) {
                    $statusClass = if ($r.Status -eq "Success") { "success" } else { "failed" }
                    $html += @"
            <tr>
                <td>$($r.Number)</td>
                <td>$($r.Title)</td>
                <td>$($r.Category)</td>
                <td class="$statusClass">$($r.Status)</td>
                <td>$($r.RecordCount)</td>
                <td>$($r.ExecutionTimeMs)</td>
                <td>$($r.Error)</td>
            </tr>
"@
                }

                $html += @"
        </tbody>
    </table>
</body>
</html>
"@
                $html | Out-File $outputFile
                Write-Success "`nHTML report generated: $outputFile"
            }
        }
    }

    # Exit code
    if ($failCount -gt 0) {
        Write-ColorOutput "`n⚠ Some queries failed. Review errors above.`n" "Yellow"
        exit 1
    } else {
        Write-ColorOutput "`n✓ All queries executed successfully!`n" "Green"
        exit 0
    }
}

# Run main
Main
