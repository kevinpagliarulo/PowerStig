<#
.SYNOPSIS
    Sample PowerSTIG configuration for Windows Server 2022

.DESCRIPTION
    Demonstrates PowerSTIG configuration using xPSDesiredStateConfiguration module
    to generate STIG compliance configuration for Windows Server 2022.
    
    This configuration applies DISA STIGs for:
    - Windows Server 2022 (Member Server)
    - Windows Defender
    - Windows Firewall
    - .NET Framework 4

.PARAMETER OutputPath
    Path where the compiled MOF files will be saved
    Default: C:\DSC\WindowsServer2022

.PARAMETER ComputerName
    Target computer name(s) for the configuration
    Default: localhost

.PARAMETER OrgSettings
    Path to organizational settings XML file (optional)
    Used to override default STIG settings with org-specific values

.PARAMETER SkipRules
    Array of STIG rule IDs to skip (optional)
    Example: @('V-254238', 'V-254239')

.EXAMPLE
    .\Test-WindowsServer2022.ps1
    
    Generates MOF for localhost with default settings

.EXAMPLE
    .\Test-WindowsServer2022.ps1 -OutputPath C:\Temp\DSC -ComputerName "Server01"
    
    Generates MOF for Server01 in specified path

.EXAMPLE
    .\Test-WindowsServer2022.ps1 -SkipRules @('V-254238') -OrgSettings C:\Settings\OrgSettings.xml
    
    Generates MOF with organizational settings and skipped rules

.NOTES
    Prerequisites:
    - PowerShell 5.1 (for compilation)
    - PowerSTIG module (migrated to xPSDesiredStateConfiguration)
    - xPSDesiredStateConfiguration v9.2.1+
    - Run with administrative privileges
    
    Testing:
    - Compile in PowerShell 5.1
    - Apply with Start-DscConfiguration
    - Can be packaged for Azure Machine Configuration
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = 'C:\DSC\WindowsServer2022MS',
    
    [Parameter()]
    [string[]]$ComputerName = 'localhost',
    
    [Parameter()]
    [string]$OrgSettings = "$PSScriptRoot\OrgSettings-WindowsServer2022MS.xml",
    
    [Parameter()]
    [string[]]$SkipRules = @(
        'V-254444.a',  # Root Certificate - Additional cert requirement
        'V-254444.b'  # Root Certificate - Additional cert requirement
    )
)

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Verify required modules are installed
if (-not (Get-Module -Name PowerStig -ListAvailable))
{
    throw "PowerStig module not found. Run .\Install-MigratedModule.ps1 first."
}

if (-not (Get-Module -Name xPSDesiredStateConfiguration -ListAvailable))
{
    throw "xPSDesiredStateConfiguration not found. Run: Install-Module -Name xPSDesiredStateConfiguration -MinimumVersion 9.2.1"
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "PowerSTIG Windows Server 2022" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

Write-Host "Configuration Details:" -ForegroundColor Yellow
Write-Host "  Target: $($ComputerName -join ', ')" -ForegroundColor Gray
Write-Host "  Output: $OutputPath" -ForegroundColor Gray
Write-Host "  Org Settings: $(if($OrgSettings){"$OrgSettings"}else{"None"})" -ForegroundColor Gray
Write-Host "  Skip Rules: $(if($SkipRules){"$($SkipRules.Count) rules"}else{"None"})`n" -ForegroundColor Gray

# Configuration Definition
configuration WindowsServer2022MS_STIG
{
    param
    (
        [Parameter()]
        [string[]]$NodeName = 'localhost',
        
        [Parameter()]
        [string]$OrgSettingsPath,
        
        [Parameter()]
        [string[]]$SkipRuleList
    )

    # Import required DSC resources
    Import-DscResource -ModuleName PowerStig -ModuleVersion '4.27.0'
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion '9.2.1'
    Import-DscResource -ModuleName SecurityPolicyDsc -ModuleVersion '2.10.0.0'
    Import-DscResource -ModuleName AuditPolicyDsc -ModuleVersion '1.4.0.0'
    Import-DscResource -ModuleName WindowsDefenderDsc -ModuleVersion '2.2.0'
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion '8.4.0'
    Import-DscResource -ModuleName GPRegistryPolicyDsc -ModuleVersion '1.3.1'
    Import-DscResource -ModuleName AccessControlDsc -ModuleVersion '1.4.3'
    Import-DscResource -ModuleName AuditSystemDsc -ModuleVersion '1.1.0'
    Import-DscResource -ModuleName FileContentDsc -ModuleVersion '1.3.0.151'
    Import-DscResource -ModuleName xWebAdministration -ModuleVersion '3.2.0'
    Import-DscResource -ModuleName SqlServerDsc -ModuleVersion '15.1.1'
    Import-DscResource -ModuleName xDnsServer -ModuleVersion '1.16.0.0'
    Import-DscResource -ModuleName CertificateDsc -ModuleVersion '5.0.0'


    Node 'localhost'
    {
        # Windows Server 2022 Member Server STIG
        # DISA STIG Version 2, Release 5 (latest as of migration)
        # Change OsRole to 'DC' if target is a Domain Controller
        WindowsServer Server2022BaselineMemberServer
        {
            OsVersion   = '2022'
            OsRole      = 'MS'  # MS = Member Server, DC = Domain Controller
            StigVersion = '2.5'
            ForestName  = 'kevinpagliarulo.com'
            DomainName  = 'kevinpagliarulo.com'
            SkipRule    = $SkipRuleList
            OrgSettings = $OrgSettingsPath
        }

        # Windows Defender STIG
        WindowsDefender DefenderSTIG
        {
            StigVersion = '2.4'
        }

        <#
        # Optional: Add additional STIGs as needed
        
        
        
        # Windows Firewall STIG
        WindowsFirewall FirewallSTIG
        {
            StigVersion = '2.2'
        }
        
       # Microsoft Edge (if applicable)
        Edge EdgeSTIG
        {
            StigVersion = '2.3'
        }

        # Internet Explorer 11 (if applicable)
        InternetExplorer IE11STIG
        {
            BrowserVersion = '11'
            StigVersion    = '2.10'
        }
        
        # IIS (if web server role installed)
        IisServer IIS10STIG
        {
            StigVersion = '25.7'
            
            # Specify IIS log path
            LogPath     = 'C:\inetpub\logs\LogFiles'
        }
        #>
    }
}

# Create output directory
if (-not (Test-Path $OutputPath))
{
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "Created output directory: $OutputPath`n" -ForegroundColor Green
}

try
{
    Write-Host "Compiling DSC Configuration..." -ForegroundColor Yellow
    
    # Build configuration data
    $configData = @{
        AllNodes = @(
            @{
                NodeName                    = '*'
                PSDscAllowPlainTextPassword = $true
                PSDscAllowDomainUser        = $true
            }
        )
    }
    
    # Add each computer to configuration
    foreach ($computer in $ComputerName)
    {
        $configData.AllNodes += @{
            NodeName = $computer
        }
    }
    
    # Compile the configuration
    $compileParams = @{
        NodeName          = $ComputerName
        OutputPath        = $OutputPath
        ConfigurationData = $configData
    }
    
    Write-Host "Debug - CompileParams:" -ForegroundColor Magenta
    $compileParams | Format-Table | Out-Host
    
    if ($OrgSettings)
    {
        $compileParams.OrgSettingsPath = $OrgSettings
    }
    
    if ($SkipRules)
    {
        $compileParams.SkipRuleList = $SkipRules
    }
    
    WindowsServer2022MS_STIG @compileParams
    
    Write-Host ""
    Write-Host "Configuration compiled successfully!" -ForegroundColor Green
    Write-Host "MOF files located at: $OutputPath" -ForegroundColor Gray
    Write-Host ""
    
    # Display generated files
    $mofFiles = Get-ChildItem -Path $OutputPath -Filter "*.mof" -File
    Write-Host "Generated Files:" -ForegroundColor Yellow
    foreach ($file in $mofFiles)
    {
        $sizeKB = [math]::Round($file.Length / 1024, 2)
        Write-Host "  - $($file.Name) - Size: $sizeKB KB" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host ""
    
    # Next steps
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Next Steps" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Option 1 - Test Locally:" -ForegroundColor Yellow
    Write-Host "  # Test configuration without applying" -ForegroundColor Gray
    Write-Host "  Test-DscConfiguration -Path '$OutputPath' -Verbose" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Apply configuration" -ForegroundColor Gray
    Write-Host "  Start-DscConfiguration -Path '$OutputPath' -Wait -Verbose -Force" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Check compliance status" -ForegroundColor Gray
    Write-Host "  Get-DscConfiguration" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Option 2 - Package for Azure Machine Configuration:" -ForegroundColor Yellow
    Write-Host "  See: .\Azure-MachineConfiguration-Guide.ps1" -ForegroundColor White
    Write-Host "  Or run: Get-Help .\Azure-MachineConfiguration-Guide.ps1 -Detailed" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Option 3 - Generate STIG Checklist:" -ForegroundColor Yellow
    Write-Host "  New-StigCheckList -ReferenceConfiguration '$OutputPath\localhost.mof' -OutputPath 'C:\Checklists' -ManualCheckFile 'C:\ManualChecks.xml'" -ForegroundColor White
    Write-Host ""
    
}
catch
{
    Write-Host "`n✗ Configuration compilation failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)`n" -ForegroundColor Red
    throw
}
