<#
.SYNOPSIS
    Fixes the null reference bug in AccessControlDSC v1.4.3 NTFSAccessEntry resource

.DESCRIPTION
    This script fixes a bug in AccessControlDSC v1.4.3 where the Compare-NtfsRule function
    fails with "Cannot bind argument to parameter 'DifferenceRule' because it is null"
    when $Actual parameter is null.
    
    The fix ensures $Actual is always an array (even if empty) before being passed to
    Test-FileSystemAccessRuleMatch.

.NOTES
    Bug occurs when:
    - STIG XML has empty <Type> elements in AccessControlEntry
    - Test-TargetResource is called during Guest Configuration compliance checking
    - $actualAce is null or empty after filtering
#>

$filePath = 'C:\Users\kepaglia\Documents\PowerShell\Modules\AccessControlDSC\1.4.3\DscResources\NTFSAccessEntry\NTFSAccessEntry.psm1'

if (-not (Test-Path $filePath))
{
    Write-Error "AccessControlDSC v1.4.3 not found at expected location: $filePath"
    exit 1
}

Write-Host "`nFixing AccessControlDSC v1.4.3 NTFSAccessEntry null reference bug..." -ForegroundColor Cyan

# Backup original file
$backupPath = "$filePath.bak"
if (-not (Test-Path $backupPath))
{
    Copy-Item $filePath $backupPath -Force
    Write-Host "  ✓ Created backup: $backupPath" -ForegroundColor Green
}

# Read the file
$content = Get-Content $filePath

# Find the Compare-NtfsRule function
$functionStartLine = -1
for ($i = 0; $i -lt $content.Count; $i++)
{
    if ($content[$i] -match 'Function\s+Compare-NtfsRule')
    {
        $functionStartLine = $i
        break
    }
}

if ($functionStartLine -eq -1)
{
    Write-Error "Could not find Compare-NtfsRule function in $filePath"
    exit 1
}

Write-Host "  ✓ Found Compare-NtfsRule function at line $($functionStartLine + 1)" -ForegroundColor Green

# Find the line with "$results = @()" which is after the param block
$insertAfterLine = -1
for ($i = $functionStartLine; $i -lt ($functionStartLine + 50); $i++)
{
    if ($content[$i] -match '^\s*\$results\s*=\s*@\(\)\s*$')
    {
        $insertAfterLine = $i - 1  # Insert before $results = @()
        break
    }
}

if ($insertAfterLine -eq -1)
{
    Write-Error "Could not find insertion point in Compare-NtfsRule function"
    exit 1
}

# Check if fix is already applied
$checkLine = $insertAfterLine + 1
if ($content[$checkLine] -match 'FIX.*Ensure.*Actual.*is always an array')
{
    Write-Host "  ℹ Fix already applied - skipping" -ForegroundColor Yellow
    exit 0
}

# Insert the fix
$fixLines = @(
    '',
    '    # FIX: Ensure $Actual is always an array to prevent null reference errors',
    '    if ($null -eq $Actual) {',
    '        $Actual = @()',
    '    }'
)

$newContent = @()
$newContent += $content[0..$insertAfterLine]
$newContent += $fixLines
$newContent += $content[($insertAfterLine + 1)..($content.Count - 1)]

# Write the fixed content
Set-Content -Path $filePath -Value $newContent -Encoding UTF8

Write-Host "  ✓ Applied fix at line $($insertAfterLine + 2)" -ForegroundColor Green
Write-Host "`n✓ Fix completed successfully!`n" -ForegroundColor Green

# Show the fixed section
Write-Host "Fixed code preview:" -ForegroundColor Cyan
$preview = $newContent[($insertAfterLine - 2)..($insertAfterLine + 10)]
foreach ($line in $preview)
{
    Write-Host "  $line" -ForegroundColor Gray
}
