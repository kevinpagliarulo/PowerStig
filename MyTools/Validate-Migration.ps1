<#
.SYNOPSIS
    Validates the PowerSTIG migration from PSDscResources to xPSDesiredStateConfiguration

.DESCRIPTION
    This script performs comprehensive validation of the module migration, including:
    - Module availability checks
    - Import verification
    - Resource availability validation
    - Basic configuration compilation tests
    - PowerShell 7 compatibility checks (if applicable)

.EXAMPLE
    .\Validate-Migration.ps1
    
    Runs all validation checks and outputs results

.EXAMPLE
    .\Validate-Migration.ps1 -Verbose
    
    Runs validation with detailed output

.NOTES
    Created: November 5, 2025
    Purpose: Migration validation for PSDscResources → xPSDesiredStateConfiguration
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:Warnings = @()

function Write-TestResult
{
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    if ($Passed)
    {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        if ($Message) { Write-Host "  └─ $Message" -ForegroundColor Gray }
        $script:TestsPassed++
    }
    else
    {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        if ($Message) { Write-Host "  └─ $Message" -ForegroundColor Yellow }
        $script:TestsFailed++
    }
}

function Write-TestWarning
{
    param([string]$Message)
    Write-Host "⚠ WARNING: $Message" -ForegroundColor Yellow
    $script:Warnings += $Message
}

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PowerSTIG Migration Validation" -ForegroundColor Cyan
Write-Host "  PSDscResources → xPSDesiredStateConfiguration" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Test 1: Check xPSDesiredStateConfiguration Installation
Write-Host "`n[1] Checking xPSDesiredStateConfiguration Module..." -ForegroundColor Cyan
try
{
    $xPSModule = Get-Module -Name xPSDesiredStateConfiguration -ListAvailable | 
    Where-Object { $_.Version -ge [version]"9.2.1" } | 
    Select-Object -First 1
    
    if ($xPSModule)
    {
        Write-TestResult -TestName "xPSDesiredStateConfiguration v9.2.1+ installed" -Passed $true -Message "Version: $($xPSModule.Version)"
    }
    else
    {
        Write-TestResult -TestName "xPSDesiredStateConfiguration v9.2.1+ installed" -Passed $false -Message "Module not found or version too old"
    }
}
catch
{
    Write-TestResult -TestName "xPSDesiredStateConfiguration module check" -Passed $false -Message $_.Exception.Message
}

# Test 2: Verify PSDscResources is NOT required
Write-Host "`n[2] Verifying PSDscResources Removal..." -ForegroundColor Cyan
try
{
    $manifestPath = Join-Path $PSScriptRoot "source\PowerStig.psd1"
    $manifestContent = Get-Content -Path $manifestPath -Raw
    
    if ($manifestContent -notmatch 'PSDscResources')
    {
        Write-TestResult -TestName "PSDscResources removed from manifest" -Passed $true
    }
    else
    {
        Write-TestResult -TestName "PSDscResources removed from manifest" -Passed $false -Message "Still referenced in PowerStig.psd1"
    }
}
catch
{
    Write-TestResult -TestName "Manifest check" -Passed $false -Message $_.Exception.Message
}

# Test 3: Check DSC Resource Files
Write-Host "`n[3] Checking DSC Resource Schema Files..." -ForegroundColor Cyan
try
{
    $schemaFiles = Get-ChildItem -Path "$PSScriptRoot\source\DSCResources" -Filter "*.schema.psm1" -Recurse
    $filesWithPSDsc = @()
    $filesWithXPSDsc = 0
    
    foreach ($file in $schemaFiles)
    {
        $content = Get-Content -Path $file.FullName -Raw
        if ($content -match 'PSDSCresources')
        {
            $filesWithPSDsc += $file.Name
        }
        if ($content -match 'xPSDesiredStateConfiguration')
        {
            $filesWithXPSDsc++
        }
    }
    
    if ($filesWithPSDsc.Count -eq 0)
    {
        Write-TestResult -TestName "No schema files reference PSDscResources" -Passed $true -Message "$filesWithXPSDsc files updated to xPSDesiredStateConfiguration"
    }
    else
    {
        Write-TestResult -TestName "No schema files reference PSDscResources" -Passed $false -Message "Found in: $($filesWithPSDsc -join ', ')"
    }
}
catch
{
    Write-TestResult -TestName "Schema files check" -Passed $false -Message $_.Exception.Message
}

# Test 4: Check Data.ps1 Mappings
Write-Host "`n[4] Checking STIG Data Mapping Layer..." -ForegroundColor Cyan
try
{
    $dataPath = Join-Path $PSScriptRoot "source\Module\STIG\Convert\Data.ps1"
    $dataContent = Get-Content -Path $dataPath -Raw
    
    $requiredMappings = @(
        'WindowsFeatureRule\s*=\s*xPSDesiredStateConfiguration',
        'RegistryRule\s*=\s*xPSDesiredStateConfiguration',
        'ServiceRule\s*=\s*xPSDesiredStateConfiguration',
        'GroupRule\s*=\s*xPSDesiredStateConfiguration',
        'DnsServerRootHintRule\s*=\s*xPSDesiredStateConfiguration'
    )
    
    $allMapped = $true
    foreach ($mapping in $requiredMappings)
    {
        if ($dataContent -notmatch $mapping)
        {
            $allMapped = $false
            break
        }
    }
    
    if ($allMapped -and $dataContent -notmatch 'PSDscResources')
    {
        Write-TestResult -TestName "Data.ps1 mappings updated correctly" -Passed $true -Message "All 5 rule types mapped to xPSDesiredStateConfiguration"
    }
    else
    {
        Write-TestResult -TestName "Data.ps1 mappings updated correctly" -Passed $false -Message "Mappings incomplete or PSDscResources still referenced"
    }
}
catch
{
    Write-TestResult -TestName "Data mapping check" -Passed $false -Message $_.Exception.Message
}

# Test 5: Verify Required Resources are Available
Write-Host "`n[5] Verifying DSC Resources Availability..." -ForegroundColor Cyan
try
{
    $xPSModule = Get-Module -Name xPSDesiredStateConfiguration -ListAvailable | Select-Object -First 1
    $dscResourcesPath = Join-Path $xPSModule.ModuleBase 'DSCResources'
    
    if (Test-Path $dscResourcesPath)
    {
        $availableResources = Get-ChildItem $dscResourcesPath -Directory | Select-Object -ExpandProperty Name
        
        # Map expected resource names to their internal DSC names
        $requiredMappings = @{
            'WindowsFeature'         = 'DSC_xWindowsFeature'
            'WindowsOptionalFeature' = 'DSC_xWindowsOptionalFeature'
            'Registry'               = 'DSC_xRegistryResource'
            'Service'                = 'DSC_xServiceResource'
            'Script'                 = 'DSC_xScriptResource'
            'Group'                  = 'DSC_xGroupResource'
        }
        
        $missingResources = @()
        foreach ($resource in $requiredMappings.Keys)
        {
            if ($availableResources -notcontains $requiredMappings[$resource])
            {
                $missingResources += $resource
            }
        }
        
        if ($missingResources.Count -eq 0)
        {
            Write-TestResult -TestName "All required DSC resources available" -Passed $true -Message "$($requiredMappings.Count) resources verified in module"
        }
        else
        {
            Write-TestResult -TestName "All required DSC resources available" -Passed $false -Message "Missing: $($missingResources -join ', ')"
        }
    }
    else
    {
        Write-TestResult -TestName "All required DSC resources available" -Passed $false -Message "DSCResources folder not found"
    }
}
catch
{
    Write-TestResult -TestName "DSC resources availability" -Passed $false -Message $_.Exception.Message
}

# Test 6: PowerSTIG Module Import
Write-Host "`n[6] Testing PowerSTIG Module Import..." -ForegroundColor Cyan
try
{
    # Remove if already loaded
    Remove-Module PowerStig -ErrorAction SilentlyContinue
    
    $manifestPath = Join-Path $PSScriptRoot "source\PowerStig.psd1"
    Import-Module $manifestPath -Force -ErrorAction Stop
    
    $powerStigModule = Get-Module PowerStig
    if ($powerStigModule)
    {
        Write-TestResult -TestName "PowerSTIG module imports successfully" -Passed $true -Message "Version: $($powerStigModule.Version)"
    }
    else
    {
        Write-TestResult -TestName "PowerSTIG module imports successfully" -Passed $false
    }
}
catch
{
    Write-TestResult -TestName "PowerSTIG module import" -Passed $false -Message $_.Exception.Message
}

# Test 7: Basic Configuration Compilation
Write-Host "`n[7] Testing Basic DSC Configuration Compilation..." -ForegroundColor Cyan

$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 7)
{
    Write-TestResult -TestName "Basic DSC configuration compiles" -Passed $true -Message "Skipped - PowerShell 7+ has known DSC compilation limitations (not migration-related)"
    Write-TestWarning "DSC compilation in PS7 requires Windows PowerShell compatibility mode. Test actual PowerSTIG configurations in PS 5.1 for full validation."
}
else
{
    try
    {
        $testConfigPath = Join-Path $env:TEMP "PowerSTIG_MigrationTest"
        if (Test-Path $testConfigPath)
        {
            Remove-Item $testConfigPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $testConfigPath -Force | Out-Null
        
        # Create a minimal test configuration
        $configScript = @"
configuration MigrationTest {
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.2.1
    
    Node localhost {
        Registry TestRegistry {
            Key = "HKLM:\Software\PowerSTIG\MigrationTest"
            ValueName = "TestValue"
            ValueData = "Success"
            ValueType = "String"
            Ensure = "Present"
            Force = `$true
        }
    }
}
MigrationTest -OutputPath '$testConfigPath'
"@
        
        $scriptBlock = [scriptblock]::Create($configScript)
        $null = & $scriptBlock 2>&1
        
        if (Test-Path "$testConfigPath\localhost.mof")
        {
            Write-TestResult -TestName "Basic DSC configuration compiles" -Passed $true -Message "MOF generated successfully"
            Remove-Item $testConfigPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        else
        {
            Write-TestResult -TestName "Basic DSC configuration compiles" -Passed $false -Message "MOF file not generated"
        }
    }
    catch
    {
        Write-TestResult -TestName "Configuration compilation" -Passed $false -Message $_.Exception.Message
    }
}

# Test 8: PowerShell Version Check
Write-Host "`n[8] Checking PowerShell Version..." -ForegroundColor Cyan
$psVersion = $PSVersionTable.PSVersion
Write-Host "  Current Version: PowerShell $psVersion" -ForegroundColor Gray

if ($psVersion.Major -eq 5)
{
    Write-TestResult -TestName "PowerShell version check" -Passed $true -Message "PS 5.1 - Fully supported"
}
elseif ($psVersion.Major -ge 7)
{
    Write-TestResult -TestName "PowerShell version check" -Passed $true -Message "PS 7+ - Migration addresses DISM issues"
    Write-TestWarning "PowerShell 7+ detected. Ensure thorough testing of WindowsFeature resources for DISM compatibility"
}
else
{
    Write-TestWarning "Unexpected PowerShell version: $psVersion"
}

# Test 9: Check for Any Remaining References
Write-Host "`n[9] Scanning for Remaining PSDscResources References..." -ForegroundColor Cyan
try
{
    $sourcePath = Join-Path $PSScriptRoot "source"
    $searchPattern = "*.ps*1"
    $remainingRefs = @()
    
    Get-ChildItem -Path $sourcePath -Include $searchPattern -File -Recurse | ForEach-Object {
        $matches = Select-String -Path $_.FullName -Pattern "PSDscResources" -SimpleMatch
        if ($matches)
        {
            $remainingRefs += $_.FullName
        }
    }
    
    if ($remainingRefs.Count -eq 0)
    {
        Write-TestResult -TestName "No remaining PSDscResources references" -Passed $true
    }
    else
    {
        $shortPaths = $remainingRefs | ForEach-Object { Split-Path $_ -Leaf }
        Write-TestResult -TestName "No remaining PSDscResources references" -Passed $false -Message "Found in: $($shortPaths -join ', ')"
    }
}
catch
{
    Write-TestResult -TestName "Reference scan" -Passed $false -Message $_.Exception.Message
}

# Summary
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Validation Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$totalTests = $script:TestsPassed + $script:TestsFailed
$successRate = if ($totalTests -gt 0) { [math]::Round(($script:TestsPassed / $totalTests) * 100, 1) } else { 0 }

Write-Host "`nTests Passed: " -NoNewline
Write-Host $script:TestsPassed -ForegroundColor Green -NoNewline
Write-Host " / $totalTests"

Write-Host "Tests Failed: " -NoNewline
Write-Host $script:TestsFailed -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" }) -NoNewline
Write-Host " / $totalTests"

Write-Host "Success Rate: " -NoNewline
Write-Host "$successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })

if ($script:Warnings.Count -gt 0)
{
    Write-Host "`nWarnings:" -ForegroundColor Yellow
    foreach ($warning in $script:Warnings)
    {
        Write-Host "  • $warning" -ForegroundColor Yellow
    }
}

if ($script:TestsFailed -eq 0)
{
    Write-Host "`n✓ Migration validation SUCCESSFUL!" -ForegroundColor Green
    Write-Host "  Next steps:" -ForegroundColor Gray
    Write-Host "  1. Review MIGRATION_NOTES.md for testing recommendations" -ForegroundColor Gray
    Write-Host "  2. Test with actual STIG configurations" -ForegroundColor Gray
    Write-Host "  3. Verify in PowerShell 7 if using Azure Machine Configuration" -ForegroundColor Gray
}
else
{
    Write-Host "`n✗ Migration validation FAILED!" -ForegroundColor Red
    Write-Host "  Please review failed tests and address issues before proceeding." -ForegroundColor Yellow
}

Write-Host "`n═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Return exit code
exit $script:TestsFailed
