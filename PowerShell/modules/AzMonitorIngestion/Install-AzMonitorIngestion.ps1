<#
.SYNOPSIS
    Automated installation script for AzMonitorIngestion PowerShell module
    
.DESCRIPTION
    This script automates the installation of the AzMonitorIngestion module
    by copying files to the PowerShell modules directory and verifying installation.
    
.PARAMETER InstallPath
    Custom installation path (optional). Defaults to user's PowerShell modules directory.
    
.PARAMETER Force
    Overwrite existing installation if found
    
.EXAMPLE
    .\Install-AzMonitorIngestion.ps1
    
.EXAMPLE
    .\Install-AzMonitorIngestion.ps1 -Force
    
.EXAMPLE
    .\Install-AzMonitorIngestion.ps1 -InstallPath "C:\CustomPath\Modules"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$InstallPath,
    
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

Write-Host "=== AzMonitorIngestion Module Installation ===" -ForegroundColor Cyan
Write-Host ""

#region Determine installation path
if ($InstallPath) {
    $modulePath = Join-Path $InstallPath "AzMonitorIngestion"
    Write-Host "Using custom installation path: $modulePath" -ForegroundColor Yellow
}
else {
    # Use standard PowerShell modules path
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $modulePath = Join-Path $HOME "Documents/PowerShell/Modules/AzMonitorIngestion"
    }
    else {
        $modulePath = Join-Path $HOME "Documents/WindowsPowerShell/Modules/AzMonitorIngestion"
    }
    Write-Host "Using standard installation path: $modulePath"
}
#endregion

#region Check for existing installation
if (Test-Path $modulePath) {
    if ($Force) {
        Write-Warning "Existing installation found. Removing (Force specified)..."
        Remove-Item -Path $modulePath -Recurse -Force
    }
    else {
        Write-Warning "Module already installed at: $modulePath"
        $response = Read-Host "Overwrite existing installation? (Y/N)"
        if ($response -ne 'Y') {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            exit 0
        }
        Remove-Item -Path $modulePath -Recurse -Force
    }
}
#endregion

#region Create directory and copy files
Write-Host ""
Write-Host "Creating module directory..." -NoNewline
New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
Write-Host " Done" -ForegroundColor Green

Write-Host "Copying module files..." -NoNewline

# Get current script location
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Files to copy
$files = @(
    'AzMonitorIngestion.psm1',
    'AzMonitorIngestion.psd1',
    'README.md',
    'QUICKSTART.md',
    'Examples.ps1',
    'LICENSE',
    'PACKAGE-OVERVIEW.md'
)

$copiedFiles = 0
foreach ($file in $files) {
    $sourcePath = Join-Path $scriptPath $file
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $modulePath -Force
        $copiedFiles++
    }
    else {
        Write-Warning "`nFile not found: $file"
    }
}

Write-Host " Done ($copiedFiles files)" -ForegroundColor Green
#endregion

#region Check prerequisites
Write-Host ""
Write-Host "Checking prerequisites..." -NoNewline

# Check for Az.Accounts module
$azAccountsModule = Get-Module -Name Az.Accounts -ListAvailable

if (-not $azAccountsModule) {
    Write-Host " Missing!" -ForegroundColor Red
    Write-Host ""
    Write-Warning "Az.Accounts module is required but not installed."
    $response = Read-Host "Install Az.Accounts now? (Y/N)"
    
    if ($response -eq 'Y') {
        Write-Host "Installing Az.Accounts module (this may take a few minutes)..." -ForegroundColor Yellow
        Install-Module -Name Az.Accounts -Scope CurrentUser -Force -AllowClobber
        Write-Host "✓ Az.Accounts installed successfully" -ForegroundColor Green
    }
    else {
        Write-Warning "Please install Az.Accounts manually: Install-Module Az.Accounts"
    }
}
else {
    Write-Host " OK" -ForegroundColor Green
    Write-Host "  Version: $($azAccountsModule[0].Version)"
}
#endregion

#region Import and verify
Write-Host ""
Write-Host "Importing module..." -NoNewline

try {
    Import-Module AzMonitorIngestion -Force -ErrorAction Stop
    Write-Host " Done" -ForegroundColor Green
    
    # Verify functions are available
    $functions = Get-Command -Module AzMonitorIngestion
    Write-Host "  Available functions: $($functions.Count)"
    
    Write-Host ""
    Write-Host "=== Installation Successful! ===" -ForegroundColor Green
    Write-Host ""
    
    # Display module info
    Get-AzMonitorModuleInfo
    
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Review QUICKSTART.md for getting started guide"
    Write-Host "2. Review Examples.ps1 for usage examples"
    Write-Host "3. Run: Get-Help Connect-AzMonitorIngestion -Full"
    Write-Host ""
    Write-Host "Module installed at: $modulePath" -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Host " Failed!" -ForegroundColor Red
    Write-Error "Failed to import module: $_"
    Write-Host ""
    Write-Host "Installation completed but module import failed." -ForegroundColor Yellow
    Write-Host "Please check the error above and try importing manually:" -ForegroundColor Yellow
    Write-Host "  Import-Module $modulePath\AzMonitorIngestion.psd1" -ForegroundColor Yellow
    exit 1
}
#endregion

#region Create desktop shortcut (optional)
$createShortcut = Read-Host "Create desktop shortcut to documentation? (Y/N)"
if ($createShortcut -eq 'Y') {
    try {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "AzMonitorIngestion-Docs.url"
        
        # Create URL shortcut to README
        $readmePath = Join-Path $modulePath "README.md"
        $urlContent = @"
[InternetShortcut]
URL=file:///$($readmePath.Replace('\', '/'))
"@
        $urlContent | Out-File -FilePath $shortcutPath -Encoding ASCII
        
        Write-Host "✓ Desktop shortcut created" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not create desktop shortcut: $_"
    }
}
#endregion

Write-Host ""
Write-Host "Installation complete! Happy ingesting! 🚀" -ForegroundColor Green
Write-Host ""
