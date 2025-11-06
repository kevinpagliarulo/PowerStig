# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

data xmlAttribute
{
    ConvertFrom-StringData -StringData @'
        ruleId                = id
        ruleSeverity          = severity
        ruleConversionStatus  = conversionstatus
        ruleTitle             = title
        ruleDscResource       = dscresource
        ruleDscResourceModule = dscresourcemodule

        organizationalSettingValue = value
'@
}

data dscResourceModule
{
    ConvertFrom-StringData -StringData @'
        AccountPolicyRule                    = SecurityPolicyDsc
        AuditPolicyRule                      = AuditPolicyDsc
        DnsServerSettingRule                 = xDnsServer
        DnsServerRootHintRule                = xPSDesiredStateConfiguration
        DocumentRule                         = None
        GroupRule                            = xPSDesiredStateConfiguration
        IisLoggingRule                       = xWebAdministration
        MimeTypeRule                         = xWebAdministration
        ManualRule                           = None
        PermissionRule                       = AccessControlDsc
        ProcessMitigationRule                = WindowsDefenderDsc
        RegistryRule                         = xPSDesiredStateConfiguration
        SecurityOptionRule                   = SecurityPolicyDsc
        ServiceRule                          = xPSDesiredStateConfiguration
        SqlScriptQueryRule                   = SqlServerDsc
        UserRightRule                        = SecurityPolicyDsc
        WebAppPoolRule                       = xWebAdministration
        WebConfigurationPropertyRule         = xWebAdministration
        WindowsFeatureRule                   = xPSDesiredStateConfiguration
        WinEventLogRule                      = xWinEventLog
        SslSettingsRule                      = xWebAdministration
        AuditSettingRule                     = AuditSystemDsc
        FileContentRule                      = FileContentDsc
        RootCertificateRule                  = CertificateDsc
        VsphereAdvancedSettingsRule          = Vmware.vSphereDSC
        VsphereServiceRule                   = Vmware.vSphereDSC
        VspherePortGroupSecurityRule         = Vmware.vSphereDSC
        VsphereAcceptanceLevelRule           = Vmware.vSphereDSC
        VsphereKernelActiveDumpPartitionRule = Vmware.vSphereDSC
        VsphereSnmpAgentRule                 = Vmware.vSphereDSC
        VsphereNtpSettingsRule               = Vmware.vSphereDSC
        VsphereVssSecurityRule               = Vmware.vSphereDSC
        nxFileLineRule                       = nx
        nxFileRule                           = nx
        nxPackageRule                        = nx
        nxServiceRule                        = nx
        SqlServerConfigurationRule           = SqlServerDsc
        SqlLoginRule                         = SqlServerDsc
        SqlProtocolRule                      = SqlServerDsc
        SqlDatabaseRule                      = SqlServerDsc
'@
}
