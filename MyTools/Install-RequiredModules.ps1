$RequiredModules = @(
    @{ModuleName = 'AuditPolicyDsc'; ModuleVersion = '1.4.0.0' },
    @{ModuleName = 'AuditSystemDsc'; ModuleVersion = '1.1.0' },
    @{ModuleName = 'AccessControlDsc'; ModuleVersion = '1.4.3' },
    @{ModuleName = 'ComputerManagementDsc'; ModuleVersion = '8.4.0' },
    @{ModuleName = 'FileContentDsc'; ModuleVersion = '1.3.0.151' },
    @{ModuleName = 'GPRegistryPolicyDsc'; ModuleVersion = '1.3.1' },
    @{ModuleName = 'xPSDesiredStateConfiguration'; ModuleVersion = '9.2.1' },
    @{ModuleName = 'SecurityPolicyDsc'; ModuleVersion = '2.10.0.0' },
    @{ModuleName = 'SqlServerDsc'; ModuleVersion = '15.1.1' },
    @{ModuleName = 'WindowsDefenderDsc'; ModuleVersion = '2.2.0' },
    @{ModuleName = 'xDnsServer'; ModuleVersion = '1.16.0.0' },
    @{ModuleName = 'xWebAdministration'; ModuleVersion = '3.2.0' },
    @{ModuleName = 'CertificateDsc'; ModuleVersion = '5.0.0' },
    @{ModuleName = 'nx'; ModuleVersion = '1.0' }
)

foreach ($module in $RequiredModules)
{
    if (-not (Get-Module -ListAvailable -Name $module.ModuleName -ErrorAction SilentlyContinue))
    {
        Install-Module -Name $module.ModuleName -RequiredVersion $module.ModuleVersion -Scope CurrentUser -Force -AllowClobber 
        #throw "The required module '$($module.ModuleName)' is not installed. Please install the module version $($module.ModuleVersion) or higher from the PowerShell Gallery and try again."
    }
}