# Quick script to test a single query interactively
param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$QueryText
)

#Requires -Modules Az.OperationalInsights

# Get workspace
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction Stop
$workspaceId = $workspace.CustomerId

Write-Host "Testing query against workspace: $($workspace.Name)" -ForegroundColor Cyan
Write-Host "Query:" -ForegroundColor Yellow
Write-Host $QueryText -ForegroundColor White
Write-Host ""

try {
    $result = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $QueryText -ErrorAction Stop
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "Record count: $($result.Results.Count)" -ForegroundColor Green
    if ($result.Results.Count -gt 0) {
        $result.Results | Format-Table
    }
} catch {
    Write-Host "FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Full error:" -ForegroundColor Yellow
    Write-Host $_.Exception | Format-List * -Force
}
