# Run this script as Administrator
# This installs the updated PowerSTIG module with explicit xPSDesiredStateConfiguration resource names

$ErrorActionPreference = 'Stop'

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Installing Updated PowerSTIG Module" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# Define paths
$sourcePath = Join-Path $PSScriptRoot "source"
$systemPath = 'C:\Program Files\WindowsPowerShell\Modules\PowerStig'
$ps51UserPath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\PowerStig"
$ps7UserPath = "$env:USERPROFILE\Documents\PowerShell\Modules\PowerStig"

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin)
{
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select Run as Administrator" -ForegroundColor Yellow
    exit 1
}

# Remove old versions
Write-Host "Removing old module versions..." -ForegroundColor Yellow
Remove-Item -Path $systemPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $ps51UserPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $ps7UserPath -Recurse -Force -ErrorAction SilentlyContinue

# Install to system-wide path (for DSC)
Write-Host "Installing to system-wide path (for DSC)..." -ForegroundColor Yellow
New-Item -Path $systemPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$sourcePath\*" -Destination $systemPath -Recurse -Force
Write-Host "Installed to: $systemPath" -ForegroundColor Green

# Install to PS 5.1 user path
Write-Host "`nInstalling to PowerShell 5.1 user path..." -ForegroundColor Yellow
New-Item -Path $ps51UserPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$sourcePath\*" -Destination $ps51UserPath -Recurse -Force
Write-Host "Installed to: $ps51UserPath" -ForegroundColor Green

# Install to PS 7 user path
Write-Host "`nInstalling to PowerShell 7 user path..." -ForegroundColor Yellow
New-Item -Path $ps7UserPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$sourcePath\*" -Destination $ps7UserPath -Recurse -Force
Write-Host "Installed to: $ps7UserPath" -ForegroundColor Green

Write-Host "`nModule installation complete!" -ForegroundColor Green

# Verify installation
Write-Host "`nVerifying installation..." -ForegroundColor Yellow
$modules = Get-Module -Name PowerStig -ListAvailable
if ($modules)
{
    Write-Host "Found $($modules.Count) module installation(s):" -ForegroundColor Green
    foreach ($module in $modules)
    {
        Write-Host "  Path: $($module.ModuleBase)" -ForegroundColor Gray
    }
}
else
{
    Write-Host "Module not found in module paths" -ForegroundColor Yellow
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "1. Close this PowerShell window" -ForegroundColor White
Write-Host "2. Open a new PowerShell 5.1 window" -ForegroundColor White
Write-Host "3. Run: powershell.exe -File .\Test-WindowsServer2022.ps1" -ForegroundColor White
Write-Host "4. Verify MOF contains xPSDesiredStateConfiguration" -ForegroundColor White
Write-Host ""
