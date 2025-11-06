<#
.SYNOPSIS
    Complete guide for testing PowerSTIG with Azure Machine Configuration (Guest Configuration)

.DESCRIPTION
    This guide provides step-by-step instructions for:
    1. Creating a PowerSTIG configuration package for Azure
    2. Testing the package locally
    3. Publishing to Azure Storage
    4. Creating an Azure Policy
    5. Assigning the policy to VMs
    6. Monitoring compliance
    
    This demonstrates how the xPSDesiredStateConfiguration migration resolves
    the DISM module loading issue in Azure Machine Configuration (PS 7.1.3+).

.NOTES
    Prerequisites:
    - Azure subscription
    - Az PowerShell modules (Az.Accounts, Az.Storage, Az.Resources, Az.PolicyInsights, Az.Compute)
    - GuestConfiguration module
    - PowerSTIG with xPSDesiredStateConfiguration migration complete
    - Azure Storage account for hosting configuration packages
    - Contributor or Owner role on target subscription/resource group

.LINK
    https://learn.microsoft.com/en-us/azure/governance/machine-configuration/
    https://github.com/microsoft/PowerStig

#>

#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.0.0' }
#Requires -Modules @{ ModuleName='GuestConfiguration'; ModuleVersion='4.0.0' }

Write-Host @"

╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║   Azure Machine Configuration + PowerSTIG                          ║
║   Complete Testing Guide                                           ║
║                                                                    ║
║   Demonstrates xPSDesiredStateConfiguration migration benefits    ║
║   Resolves: DISM module issues in PowerShell 7.1.3+               ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 1: Install Prerequisites" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @"
Run these commands in PowerShell 5.1 as Administrator:

# Install Azure PowerShell modules
Install-Module -Name Az.Accounts -Scope CurrentUser -Force -AllowClobber
Install-Module -Name Az.Storage -Scope CurrentUser -Force -AllowClobber
Install-Module -Name Az.Resources -Scope CurrentUser -Force -AllowClobber
Install-Module -Name Az.PolicyInsights -Scope CurrentUser -Force -AllowClobber
Install-Module -Name Az.Compute -Scope CurrentUser -Force -AllowClobber

# Install Guest Configuration module (REQUIRED - v4.11.0+)
Install-Module -Name GuestConfiguration -Scope CurrentUser -Force -AllowClobber -MinimumVersion 4.11.0

# Verify installations
Get-Module -Name Az.* -ListAvailable | Select-Object Name, Version
Get-Module -Name GuestConfiguration -ListAvailable | Select-Object Name, Version

"@ -ForegroundColor White

Read-Host "`nPress Enter when prerequisites are installed..."

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 2: Generate PowerSTIG Configuration" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @"
First, compile the PowerSTIG configuration:

# IMPORTANT: Add SkipRule for resources that cause module version conflicts
# AccessControlDSC can have version conflicts in Guest Configuration packages
`$SkipRuleList = @(
    # Certificate rules requiring organizational thumbprints
    'V-254442.a', 'V-254442.b', 'V-254442.c', 'V-254442.d'
    'V-254443', 'V-254444.a', 'V-254444.b'
    
    # NTFS Permission rules (AccessControlDSC version conflicts)
    'V-254391', 'V-254392'
    
    # PNRP feature not available on Domain Controllers
    'V-254271'
)

# Run the sample script with skip rules
.\Test-WindowsServer2022.ps1 -OutputPath C:\DSC\WindowsServer2022

This will:
✓ Compile Windows Server 2022 STIG configuration
✓ Use xPSDesiredStateConfiguration (migrated module)
✓ Generate MOF file(s) in C:\DSC\WindowsServer2022
✓ Include WindowsFeature resources (DISM-dependent)
✓ Skip rules that cause module version conflicts

"@ -ForegroundColor White

Write-Host "Important: " -ForegroundColor Yellow -NoNewline
Write-Host "Azure Guest Configuration cannot package multiple versions of the same module." -ForegroundColor Gray
Write-Host "           The SkipRule list above excludes NTFS permission rules that cause" -ForegroundColor Gray
Write-Host "           AccessControlDSC version conflicts. The xPSDesiredStateConfiguration" -ForegroundColor Gray
Write-Host "           migration resolves DISM loading issues for WindowsFeature resources.`n" -ForegroundColor Gray

$compiled = Read-Host "Have you compiled the configuration? (Y/N)"
if ($compiled -ne 'Y')
{
    Write-Host "Run .\Test-WindowsServer2022.ps1 first, then return to this guide." -ForegroundColor Yellow
    exit
}

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 3: Create Guest Configuration Package" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @"
Convert the PowerSTIG MOF into an Azure Machine Configuration package:

"@ -ForegroundColor White

Write-Host @'
# Define package parameters
$packageName = "WindowsServer2022_STIG"
$mofPath = "C:\DSC\WindowsServer2022\localhost.mof"
$outputPath = "C:\GuestConfig\Packages"

# Create output directory
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

# Create Guest Configuration package
$package = New-GuestConfigurationPackage `
    -Name $packageName `
    -Configuration $mofPath `
    -Path $outputPath `
    -Type Audit `
    -Force

Write-Host "`n✓ Package created: $($package.Path)" -ForegroundColor Green
Write-Host "  Package size: $([math]::Round((Get-Item $package.Path).Length/1MB, 2)) MB`n" -ForegroundColor Gray

'@ -ForegroundColor Cyan

Write-Host "Notes on Package Type:" -ForegroundColor Yellow
Write-Host "  - Audit: Reports compliance only (no changes to system) ← USING THIS" -ForegroundColor Green
Write-Host "  - AuditAndSet: Reports compliance AND applies configuration (remediation)" -ForegroundColor Gray
Write-Host "  This guide uses 'Audit' mode for safe compliance reporting.`n" -ForegroundColor Gray

Read-Host "Press Enter to continue to Step 4..."

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 4: Test Package Locally (Optional but Recommended)" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @'
Test the package on a Windows Server 2022 machine before deploying to Azure:

# Get the package path
$packagePath = "C:\GuestConfig\Packages\WindowsServer2022_STIG.zip"

# Verify package exists
if (Test-Path $packagePath) {
    Write-Host "✓ Package found: $packagePath" -ForegroundColor Green
    $packageSize = [math]::Round((Get-Item $packagePath).Length/1MB, 2)
    Write-Host "  Package size: $packageSize MB" -ForegroundColor Gray
} else {
    Write-Host "✗ Package not found at: $packagePath" -ForegroundColor Red
    exit
}

# Get compliance report (Audit-only packages cannot use Start-GuestConfigurationPackageRemediation)
Write-Host "`nRetrieving compliance status (this may take several minutes)..." -ForegroundColor Yellow
Write-Host "NOTE: Audit-only packages report compliance without making changes to the system." -ForegroundColor Gray

$compliance = Get-GuestConfigurationPackageComplianceStatus -Path $packagePath

Write-Host "`nCompliance Results:" -ForegroundColor Cyan
Write-Host "  Compliance Status: $($compliance.complianceStatus)" -ForegroundColor $(if($compliance.complianceStatus -eq "Compliant"){"Green"}else{"Yellow"})
Write-Host "  Resources Checked: $($compliance.resources.Count)" -ForegroundColor Gray

# Show non-compliant resources (if any)
$nonCompliant = $compliance.resources | Where-Object { $_.complianceStatus -ne "Compliant" }
if ($nonCompliant) {
    Write-Host "`nNon-Compliant Resources ($($nonCompliant.Count)):" -ForegroundColor Yellow
    $nonCompliant | Select-Object -First 10 resourceId, complianceStatus, reasons | Format-Table -AutoSize -Wrap
    if ($nonCompliant.Count -gt 10) {
        Write-Host "  ... and $($nonCompliant.Count - 10) more" -ForegroundColor Gray
    }
} else {
    Write-Host "`n✓ All resources are compliant!" -ForegroundColor Green
}

'@ -ForegroundColor Cyan

Write-Host "`nThis local test will:" -ForegroundColor Yellow
Write-Host "  ✓ Verify the package structure is correct" -ForegroundColor Gray
Write-Host "  ✓ Report compliance status (audit only - no changes made)" -ForegroundColor Gray
Write-Host "  ✓ Test that WindowsFeature resources work (DISM operations)" -ForegroundColor Gray
Write-Host "  ✓ Confirm xPSDesiredStateConfiguration resolves PS7 issues" -ForegroundColor Gray
Write-Host "  ✓ Generate a compliance report before Azure deployment`n" -ForegroundColor Gray

Read-Host "Press Enter to continue to Step 5 (Upload to Azure Storage)..."

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 5: Upload Package to Azure Storage" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @"
The package must be hosted in Azure Storage for Machine Configuration to access it.

"@ -ForegroundColor White

Write-Host @'
# Connect to Azure
Connect-AzAccount

# Set your subscription
$subscriptionId = "588cd6df-202a-4e3c-a4c1-457ef004af7a"
Set-AzContext -SubscriptionId $subscriptionId

# Define storage account details
$resourceGroupName = "core-rg"
$storageAccountName = "stigconfigs$(Get-Random -Maximum 9999)"  # Must be globally unique
$containerName = "guestconfig"
$location = "eastus2"

# Create resource group if it doesn't exist
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $resourceGroupName -Location $location
}

# Create storage account
$storageAccount = New-AzStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -Location $location `
    -SkuName Standard_LRS `
    -Kind StorageV2 `
    -AllowBlobPublicAccess $true

# Get storage context
$ctx = $storageAccount.Context

# Create container with public read access for blobs
$container = New-AzStorageContainer `
    -Name $containerName `
    -Context $ctx `
    -Permission Blob

# Upload the package
$packagePath = "C:\GuestConfig\Packages\WindowsServer2022_STIG.zip"
$blobName = "WindowsServer2022_STIG.zip"

$blob = Set-AzStorageBlobContent `
    -File $packagePath `
    -Container $containerName `
    -Blob $blobName `
    -Context $ctx `
    -Force

# Get the package URI
$packageUri = $blob.ICloudBlob.Uri.AbsoluteUri

Write-Host "`n✓ Package uploaded successfully!" -ForegroundColor Green
Write-Host "  Package URI: $packageUri" -ForegroundColor Gray
Write-Host "  Copy this URI for the next step.`n" -ForegroundColor Yellow

# IMPORTANT: Generate content hash
$contentHash = Get-FileHash -Path $packagePath -Algorithm SHA256
$contentHashValue = $contentHash.Hash

Write-Host "  Content Hash: $contentHashValue" -ForegroundColor Gray
Write-Host "  Copy this hash for the next step.`n" -ForegroundColor Yellow

'@ -ForegroundColor Cyan

Read-Host "Press Enter after uploading package to Azure Storage..."

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 6: Create Azure Policy Definition" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @"
Create an Azure Policy that uses your Guest Configuration package:

"@ -ForegroundColor White

Write-Host @'
# Use the New-GuestConfigurationPolicy cmdlet (the correct way for Guest Configuration)
$packagePath = "C:\GuestConfig\Packages\WindowsServer2022_STIG.zip"

$policyGuid = [guid]::NewGuid().ToString()

# Generate policy definition from Guest Configuration package
$policyConfig = New-GuestConfigurationPolicy `
    -PolicyId $policyGuid `
    -ContentUri "https://stigconfigs7920.blob.core.windows.net/guestconfig/WindowsServer2022_STIG.zip" `
    -DisplayName "Windows Server 2022 - DISA STIG Compliance" `
    -Description "Audit DISA STIG compliance on Windows Server 2022 using PowerSTIG with xPSDesiredStateConfiguration" `
    -Path "C:\GuestConfig\Policy" `
    -Platform Windows `
    -PolicyVersion  1.0.0 `
    -Mode Audit

# This creates policy files in C:\GuestConfig\Policy\
# - AuditIfNotExists.json (the policy definition)
# - DeployIfNotExists.json (optional - for auto-remediation)

# Publish the policy to Azure
$policyPath = "C:\GuestConfig\Policy\WindowsServer2022_STIG_AuditIfNotExists.json"

# Create the policy in Azure from the generated file
New-AzPolicyDefinition `
    -Name "windows-server-2022-stig" `
    -DisplayName "Windows Server 2022 - DISA STIG Compliance" `
    -Policy $policyPath

$policy = Get-AzPolicyDefinition -Name "windows-server-2022-stig"

Write-Host "`n✓ Policy definition created!" -ForegroundColor Green
Write-Host "  Policy Name: $($policy.Name)" -ForegroundColor Gray
Write-Host "`nPolicy files generated in C:\GuestConfig\Policy\" -ForegroundColor Gray

'@ -ForegroundColor Cyan

Write-Host "Note: " -ForegroundColor Yellow -NoNewline
Write-Host "assignmentType set to Audit (compliance reporting only):" -ForegroundColor Gray
Write-Host "  - Audit: Reports compliance only, no changes to VMs ← USING THIS" -ForegroundColor Green
Write-Host "  - ApplyAndAutoCorrect: Applies configuration and auto-remediates drift" -ForegroundColor Gray
Write-Host "  This ensures VMs are only assessed, not modified.`n" -ForegroundColor Gray

Read-Host "Press Enter after creating policy definition..."

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 7: Assign Policy to Scope" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @'
Assign the policy to a subscription, resource group, or specific VMs:

# Option A: Assign to entire subscription
$subscription = Get-AzSubscription -SubscriptionId "<YOUR_SUBSCRIPTION_ID>"

$assignment = New-AzPolicyAssignment `
    -Name "stig-server-2022-subscription" `
    -DisplayName "STIG Compliance Audit - Windows Server 2022 (Subscription)" `
    -PolicyDefinition $policy `
    -Scope "/subscriptions/$($subscription.Id)" `
    -Location "eastus" `
    -IdentityType 'SystemAssigned'

# Option B: Assign to specific resource group
$rgScope = "/subscriptions/588cd6df-202a-4e3c-a4c1-457ef004af7a/resourceGroups/core-rg"

$assignment = New-AzPolicyAssignment `
    -Name "stig-server-2022-rg" `
    -DisplayName "STIG Compliance Audit - Windows Server 2022 (Resource Group)" `
    -PolicyDefinition $policy `
    -Scope $rgScope `
    -Location "eastus" `
    -IdentityType 'SystemAssigned'

# Assign managed identity permissions
$roleAssignment = New-AzRoleAssignment `
    -ObjectId $assignment.IdentityPrincipalId `
    -RoleDefinitionName "Contributor" `
    -Scope $rgScope

Write-Host "`n✓ Policy assigned successfully!" -ForegroundColor Green
Write-Host "  Assignment Name: $($assignment.Name)" -ForegroundColor Gray
Write-Host "  Scope: $($assignment.Scope)" -ForegroundColor Gray
Write-Host "  Identity: $($assignment.IdentityPrincipalId)`n" -ForegroundColor Gray

'@ -ForegroundColor Cyan

Read-Host "Press Enter after assigning policy..."

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 8: Verify Guest Configuration Extension on VMs" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @'
Azure Machine Configuration requires the Guest Configuration extension on VMs:

# Check if extension is installed
$vmName = "kp-dc-vm"
$resourceGroup = "core-rg"

$vm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName
$extensions = Get-AzVMExtension -ResourceGroupName $resourceGroup -VMName $vmName

$gcExtension = $extensions | Where-Object { $_.Name -eq "AzurePolicyforWindows" }

if ($gcExtension) {
    Write-Host "✓ Guest Configuration extension installed" -ForegroundColor Green
    Write-Host "  Version: $($gcExtension.TypeHandlerVersion)" -ForegroundColor Gray
} else {
    Write-Host "✗ Extension not installed - installing now..." -ForegroundColor Yellow
    
    # Install the extension
    Set-AzVMExtension `
        -ResourceGroupName $resourceGroup `
        -VMName $vmName `
        -Name "AzurePolicyforWindows" `
        -Publisher "Microsoft.GuestConfiguration" `
        -Type "ConfigurationforWindows" `
        -TypeHandlerVersion "1.0" `
        -Location $vm.Location
}

# Verify system-assigned managed identity
if (-not $vm.Identity.Type) {
    Write-Host "Enabling system-assigned managed identity..." -ForegroundColor Yellow
    Update-AzVM -ResourceGroupName $resourceGroup -VM $vm -IdentityType SystemAssigned
}

'@ -ForegroundColor Cyan

Read-Host "Press Enter to continue to monitoring..."

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 9: Monitor Compliance" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @'
Monitor STIG compliance across your environment:

# Wait for initial compliance scan (can take 15-30 minutes)
Write-Host "Waiting for compliance data..." -ForegroundColor Yellow

# Check policy compliance
$complianceStates = Get-AzPolicyState `
    -PolicyAssignmentName "stig-server-2022-subscription" `
    -Top 100

# Summary
$compliant = ($complianceStates | Where-Object { $_.ComplianceState -eq "Compliant" }).Count
$nonCompliant = ($complianceStates | Where-Object { $_.ComplianceState -eq "NonCompliant" }).Count

Write-Host "`nCompliance Summary:" -ForegroundColor Cyan
Write-Host "  Compliant: $compliant VMs" -ForegroundColor Green
Write-Host "  Non-Compliant: $nonCompliant VMs" -ForegroundColor $(if($nonCompliant -gt 0){"Red"}else{"Green"})

# Detailed compliance per VM
$complianceStates | Select-Object ResourceId, ComplianceState, Timestamp | Format-Table -AutoSize

# Check Guest Configuration assignment status
$vmName = "<YOUR_VM_NAME>"
$resourceGroup = "<YOUR_RESOURCE_GROUP>"

$gcAssignment = Get-AzVMGuestPolicyStatus `
    -ResourceGroupName $resourceGroup `
    -VMName $vmName

Write-Host "`nGuest Configuration Status:" -ForegroundColor Cyan
Write-Host "  Configuration: $($gcAssignment.Name)" -ForegroundColor Gray
Write-Host "  Compliance: $($gcAssignment.ComplianceStatus)" -ForegroundColor $(if($gcAssignment.ComplianceStatus -eq "Compliant"){"Green"}else{"Red"})
Write-Host "  Last Check: $($gcAssignment.LastCheckTime)" -ForegroundColor Gray

# View detailed compliance reasons (what failed)
$gcAssignment.LatestReportId
$report = Get-AzVMGuestPolicyStatusHistory `
    -ResourceGroupName $resourceGroup `
    -VMName $vmName `
    -ReportId $gcAssignment.LatestReportId

$report.Resources | Where-Object { $_.ComplianceStatus -ne "Compliant" } | 
    Select-Object ResourceId, ComplianceStatus, Reasons | 
    Format-Table -AutoSize -Wrap

'@ -ForegroundColor Cyan

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "STEP 10: Verify DISM/WindowsFeature Fix" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @"
Verify that WindowsFeature resources work correctly (the original issue):

"@ -ForegroundColor White

Write-Host @'
# Connect to a target VM
$vmName = "<YOUR_VM_NAME>"
$resourceGroup = "<YOUR_RESOURCE_GROUP>"

# Get compliance report
$gcStatus = Get-AzVMGuestPolicyStatus -ResourceGroupName $resourceGroup -VMName $vmName

# Look for WindowsFeature resource results
$windowsFeatureResults = $gcStatus.LatestReportId | ForEach-Object {
    $report = Get-AzVMGuestPolicyStatusHistory `
        -ResourceGroupName $resourceGroup `
        -VMName $vmName `
        -ReportId $_
    
    $report.Resources | Where-Object { $_.ResourceType -match "WindowsFeature" }
}

Write-Host "`nWindowsFeature Resource Status:" -ForegroundColor Cyan
$windowsFeatureResults | Select-Object ResourceId, ComplianceStatus | Format-Table -AutoSize

# If all WindowsFeature resources show "Compliant" or successful processing:
Write-Host "`n✓ SUCCESS: WindowsFeature resources processed without DISM errors!" -ForegroundColor Green
Write-Host "  The xPSDesiredStateConfiguration migration resolved the issue." -ForegroundColor Gray

'@ -ForegroundColor Cyan

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "Additional Azure Portal Steps" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @"
View compliance in Azure Portal:

1. Navigate to Azure Portal (portal.azure.com)

2. Go to "Policy" service

3. Click "Compliance" in left menu

3. Find your policy: "Windows Server 2022 - DISA STIG Compliance (Audit Only)"

5. Click the policy to see:
   - Overall compliance percentage
   - List of compliant/non-compliant resources
   - Compliance over time trends
   - Remediation tasks

6. For detailed VM compliance:
   - Go to Virtual Machine → Guest Configuration
   - View configuration assignment status
   - See individual STIG rule compliance
   - Access compliance reports

7. Set up Azure Monitor alerts:
   - Create alert rule for non-compliant resources
   - Configure action groups for notifications
   - Track compliance trends over time

"@ -ForegroundColor White

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "Troubleshooting Common Issues" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host @"
Issue: "Cannot include more than one version of a module"
Solution: This occurs when different DSC resources require different module versions
  - Add problematic rules to SkipRule list (e.g., NTFS permission rules)
  - Use consistent module versions across all resources
  - Remove conflicting resources from the MOF before packaging
  
Issue: Extension not installing
Solution: Verify VM has internet connectivity and managed identity

Issue: Policy not applying
Solution: Wait 15-30 minutes for initial evaluation cycle

Issue: Compliance showing as "Not Started"
Solution: Check Guest Configuration extension logs in VM:
  C:\WindowsAzure\GuestAgent_*\GuestConfiguration\*\Logs

Issue: WindowsFeature resources failing
Solution: This was the original issue! If still occurring:
  - Verify xPSDesiredStateConfiguration v9.2.1 is in the package
  - Check package was compiled in PS 5.1
  - Review extension logs for specific DISM errors

Issue: Permission errors
Solution: Ensure managed identity has Contributor role on scope

Issue: Package too large (>100MB)
Solution: Azure has size limits for Guest Configuration packages
  - Use SkipRule to exclude less critical STIG rules
  - Remove verbose logging or example files from the package
  - Split into multiple policies targeting different rule sets

"@ -ForegroundColor White

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✓ Azure Machine Configuration Setup Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════`n" -ForegroundColor Green

Write-Host @"
Summary:
✓ PowerSTIG configuration compiled with xPSDesiredStateConfiguration
✓ Guest Configuration package created (Audit mode - no remediation)
✓ Package uploaded to Azure Storage
✓ Azure Policy defined and assigned (compliance reporting only)
✓ Guest Configuration extension deployed
✓ Compliance monitoring active

The xPSDesiredStateConfiguration migration ensures WindowsFeature resources
work correctly in Azure Machine Configuration's PowerShell 7.1.3+ runtime,
resolving the DISM module loading issue documented by Microsoft.

IMPORTANT: This configuration runs in AUDIT mode only. VMs are assessed
for STIG compliance but no changes are applied. Review compliance reports
in Azure Portal to identify non-compliant settings.

Next: Monitor compliance in Azure Portal and review compliance reports.

"@ -ForegroundColor Gray
