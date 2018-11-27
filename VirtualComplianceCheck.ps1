[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter,
    [Parameter()] $CredFile = $null
)
 
$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
$ErrorActionPreference = "SilentlyContinue"
  
Function Check-PowerCLI
{
    Param(
    )
  
    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
        write-host ("Adding PowerCLI...")
        Get-Module -Name VMware* -ListAvailable | Import-Module -Global
        write-host ("Loaded PowerCLI.")
    }
}
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  
Check-PowerCLI
 
if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}
 
Connect-vCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

##################
#Email Variables
##################
#emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "VirtualComplianceCheck@fanatics.com"
$emailTo = "fanatics+IEC@service-now.com"
$emailServer = "smtp.ff.p10"

##################
#Global Variables
##################
$ESXBuildNumber = "7388607"

#Obtain information
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Retrieving clusters (Excluding 'voice')..."
$ESXClusters = Get-Cluster | ? { $_.Name -notlike "*voice*" } | sort Name
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Retrieving hosts (Excluding 'voice')..."
$ESXHosts = $ESXClusters | Get-VMHost | ? { $_.ConnectionState -eq "Connected" } | sort Name
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Retrieving distributed switches..."
$ESXvDS = Get-VDSwitch | sort Name

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing data file..."
$DataFromFile = Import-Csv .\VirtualComplianceCheck-Data.csv

###############
# Cluster Checks excluding "voice" clusters
###############
$clusterfails = @()
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking cluster configurations..."
foreach ($ESXCluster in $ESXClusters)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing $($ESXCluster.Name)..."
    if ($ESXCluster.HAEnabled -eq $false `
     -or $ESXCluster.ExtensionData.Configuration.DasConfig.HostMonitoring -eq "disabled" `
     -or $ESXCluster.ExtensionData.Configuration.DasConfig.DefaultVmSettings.RestartPriority -eq "disabled" `
     -or $ESXCluster.ExtensionData.Configuration.DasConfig.DefaultVmSettings.IsolationResponse -ne "none" `
     -or $ESXCluster.HAAdmissionControlEnabled -eq $true `
     -or $ESXCluster.DrsEnabled -eq $false `
     -or $ESXCluster.DrsAutomationLevel -ne "FullyAutomated" `
     -or $ESXCluster.ExtensionData.ConfigurationEx.DrsConfig.VmotionRate -ne 5 `
     -or $ESXCluster.EVCMode -eq "")
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$($ESXCluster.Name) has a config problem."
        $clusterfails += New-Object PSObject -Property @{
            Cluster = $ESXCluster.Name
            "HA Enabled" = $ESXCluster.HAEnabled
            "Host Monitoring" = $ESXCluster.ExtensionData.Configuration.DasConfig.HostMonitoring
            "Host Failure Response" = $ESXCluster.ExtensionData.Configuration.DasConfig.DefaultVmSettings.RestartPriority
            "Isolation Response" = $ESXCluster.ExtensionData.Configuration.DasConfig.DefaultVmSettings.IsolationResponse
            "Admission Control" = $ESXCluster.HAAdmissionControlEnabled
            "DRS Enabled" = $ESXCluster.DrsEnabled
            "DRS Automation Level" = $ESXCluster.DrsAutomationLevel
            "DRS Migration Threshold" = $ESXCluster.ExtensionData.ConfigurationEx.DrsConfig.VmotionRate
            "EVC Mode" = $ESXCluster.EVCMode
        }
    }
}

if ($clusterfails.Count -gt 0)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing improperly configured clusters and building the email body..."
    $EmailBody = "The following cluster settings are misconfigured and their incorrect configuration settings are listed.`r`n`r`n"

    foreach ($clusterfail in $clusterfails)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding $($clusterfail.Cluster) to the email..."
        $EmailBody += "Cluster: $($clusterfail.Cluster)`r`n"

        if ($clusterfail.'HA Enabled' -eq $false) { $EmailBody += "HA Enabled: $($clusterfail.'HA Enabled')`r`n" }
        if ($clusterfail.'Host Monitoring' -eq "disabled") { $EmailBody += "Host Monitoring: $($clusterfail.'Host Monitoring')`r`n" }
        if ($clusterfail.'Host Failure Response' -eq "disabled") { $EmailBody += "Host Failure Response: $($clusterfail.'Host Failure Response')`r`n" }
        if ($clusterfail.'Isolation Response' -ne "none") { $EmailBody += "Isolation Response: $($clusterfail.'Isolation Response')`r`n" }
        if ($clusterfail.'Admission Control' -eq $true) { $EmailBody += "Admission Control: $($clusterfail.'Admission Control')`r`n" }
        if ($clusterfail.'DRS Enabled' -eq $false) { $EmailBody += "DRS Enabled: $($clusterfail.'DRS Enabled')`r`n" }
        if ($clusterfail.'DRS Automation Level' -ne "FullyAutomated") { $EmailBody += "DRS Automation Level: $($clusterfail.'DRS Automation Level')`r`n" }
        if ($clusterfail.'DRS Migration Threshold' -ne 5) { $EmailBody += "DRS Migration Threshold: $($clusterfail.'DRS Migration Threshold')`r`n" }
        if ($clusterfail.'EVC Mode' -eq "") { $EmailBody += "EVC Mode: Disabled`r`n" }

        $EmailBody += "`r`n"
    }

    $EmailBody += "Script executed on $($env:computername)."

    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "VirtualComplianceCheck found config problems in $vCenter cluster checks" -body $EmailBody
}

###############
# Host Checks
###############
$hostfails = @()
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking cluster configurations..."
foreach ($ESXHost in $ESXHosts)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing $($ESXHost.Name)..."
    
    #Checking Build number
    $OSInfo = Get-View -ViewType HostSystem -Filter @{"Name"=$($ESXHost).Name} -Property Name,Config.Product | foreach {$_.Name, $_.Config.Product}
    if ($OSInfo.Build -ne $ESXBuildNumber) { $BuildCheck = "Wrong" }
    
    #Checking correct domain name for FQDN
    $ParentCluster = $ESXHost.Parent.Name
    $ProperInfo = $DataFromFile | ? { $_.Cluster -eq $ParentCluster }
    if ($ProperInfo -eq $null -or $ProperInfo -eq "") { $ProperInfoCheck = "Wrong" }
    if ($ESXHost.Name -notlike "*$($ProperInfo.Domain)") { $FQDN = "Wrong" }

    #Checking correct NTP servers and service is setup right
    $NTPServers = Get-VMHostNtpServer $ESXHost
    $ntp = Get-VmHostService -VMhost $ESXHost | Where {$_.Key -eq 'ntpd'}
    if ($NTPServers -contains "ntp-iad-01.fanatics.corp" -and $NTPServers -contains "ntp-iad-02.fanatics.corp" -and $NTPServers -contains "ntp-dfw-01.fanatics.corp" -and $NTPServers -contains "ntp-dfw-02.fanatics.corp" -and $NTPServers.Count -eq 4)
    { $TimeServers = "Right" }
    else { $TimeServers = "Wrong" }

    if ($ntp.Policy -eq "on")
    { $TimePolicy = "Right" }
    else { $TimePolicy = "Wrong" }

    #Checking SNMP configuration
    $snmp = Get-VMHostService -VMHost $ESXHost | where {$_.Key -eq 'snmpd'}
    if ($snmp.Running -eq "True") { $SNMPState = "Wrong" }
    if ($snmp.Policy -eq "On") { $SNMPPolicy = "Wrong" }

    #Checking Domain, domain look up, DNS Servers and Gateway is correct
    $Network = Get-VMHostNetwork -VMHost $ESXHost
    if ($Network.DomainName -ne $($ProperInfo.Domain)) { $DomainName = "Wrong" }
    if ($Network.SearchDomain -ne $($ProperInfo.Domain)) { $SearchDomain = "Wrong" }
    if ($Network.VMKernelGateway -ne $($ProperInfo.Gateway)) { $VMKernelGateway = "Wrong" }
    if ($Network.DnsAddress -contains $($ProperInfo.DNS1) -and $Network.DnsAddress -contains $($ProperInfo.DNS2) -and $Network.DnsAddress.Count -eq 2) { $DNS = "Right" }
    else { $DNS = "Wrong" }

    #Check power policy
    $vmhostview = Get-View -ViewType Hostsystem -Filter @{"Name"=$($ESXHost).Name} -Property ConfigManager.PowerSystem
    $powerpolicy = Get-View $vmhostview.ConfigManager.PowerSystem
    if ($($powerpolicy.Info.CurrentPolicy.Key) -ne 1) { $PowerPolicySetting = "Wrong" }

    #Check alarm actions
    $AlarmActionState = Get-AlarmActionState -Entity $ESXHost -Recurse:$false
    if ($($AlarmActionState.'Alarm actions enabled') -ne "True") { $AlarmActions = "Wrong" }

    #Check virtual switch config
    $StandardSwitches = Get-VirtualSwitch -VMHost $ESXHost -Standard
    if ($StandardSwitches.Nic.Count -gt 0) { $StandardSwitchCheck = "Wrong" }

    $DistributedSwitches = Get-VDSwitch -VMHost $ESXHost
    if ($DistributedSwitches -eq $null -or $DistributedSwitches -eq "") { $DistributedSwitchCheck1 = "Wrong" }
    else 
    {
        foreach ($DistributedSwitch in $DistributedSwitches)
        {
            $Nics = Get-VMHostNetworkAdapter -VMHost $ESXHost -DistributedSwitch $DistributedSwitch -Physical | sort name
            if ($Nics.Count -lt 2) { $DistributedSwitchCheck2 = "Wrong" }
        }
    }

    #VAAI, ALUA, iSCSI/FC Config Check
    $StorageDevices = @($ESXHost | Get-Datastore | where {$_.type -eq "VMFS"} |   
    Select Name,  
        @{N="DisplayName";E={(Get-ScsiLun -CanonicalName ($_.ExtensionData.Info.Vmfs.Extent[0]).DiskName -VMHost (Get-VIObjectByVIView $_.ExtensionData.Host[0].Key)).ExtensionData.DisplayName}})

    if ($($StorageDevices | ? { $_.DisplayName -like "COMPELNT*" }).Count -gt 0)
    {
        $VAAIConfig1 = Get-AdvancedSetting -Entity $ESXHost -Name DataMover.HardwareAcceleratedMove
        if ($VAAIConfig1.Value -ne 1) { $VAAIConfig1Check = "Wrong" }
        $VAAIConfig2 = Get-AdvancedSetting -Entity $ESXHost -Name DataMover.HardwareAcceleratedInit
        if ($VAAIConfig2.Value -ne 1) { $VAAIConfig2Check = "Wrong" }
        $VAAIConfig3 = Get-AdvancedSetting -Entity $ESXHost -Name VMFS3.HardwareAcceleratedLocking
        if ($VAAIConfig3.Value -ne 1) { $VAAIConfig3Check = "Wrong" }

        $esxcli = Get-EsxCli -V2 -VMHost $ESXHost
        if ($($esxcli.storage.nmp.satp.list.Invoke() | where {$_.Name -eq "VMW_SATP_ALUA"}).DefaultPSP -ne "VMW_PSP_RR") { $DefaultPSP = "Wrong" }

        $CompellentVolumeCheck = $esxcli.storage.nmp.device.list.Invoke() | ? { $_.DeviceDisplayName -like "COMPELNT*" -and $_.StorageArrayType -ne "VMW_SATP_ALUA" }
        if ($CompellentVolumeCheck -ne $null) { $ = "Wrong" }

        if ($esxcli.iscsi.adapter.list.Invoke().Description -eq "iSCSI Software Adapter")
        {
            $iSCSIAdapterName = $($esxcli.iscsi.adapter.list.Invoke() | Where-Object { $_.Description -eq "iSCSI Software Adapter" }).Adapter

            $iSCSIQueueDepth = $($($esxcli.system.module.parameters.list.Invoke(@{module="iscsi_vmk"})) | Where-Object { $_.Name -eq "iscsivmk_LunQDepth" }).Value
            if ($iSCSIQueueDepth -eq $null -or $iSCSIQueueDepth -ne "255") { $iSCSIQueueDepthCheck = "Wrong" }

            $iSCSILoginTimeout = $($esxcli.iscsi.adapter.param.get.Invoke(@{adapter=$iSCSIAdapterName}) | Where-Object { $_.Name -eq "LoginTimeout" }).Current
            if ($iSCSILoginTimeout -eq $null -or $iSCSILoginTimeout -ne "5") { $iSCSILoginTimeoutCheck = "Wrong" }
        }

        if ($($esxcli.system.module.list.Invoke() | Where-Object { $_.Name -like "ql*" -or $_.Name -eq "qedentv" }).Count -ge 1)
        {
            if ($($esxcli.system.module.parameters.list.Invoke(@{module="qlnativefc"}) | Where-Object { $_.Name -eq "ql2xmaxqdepth" }).Value -ne "255") { $FCMaxQueueDepth = "Wrong" }

            if ($($esxcli.system.module.parameters.list.Invoke(@{module="qlnativefc"}) | Where-Object { $_.Name -eq "ql2xloginretrycount" }).Value -ne "60") { $FCLoginRetryCount = "Wrong" }

            if ($($esxcli.system.module.parameters.list.Invoke(@{module="qlnativefc"}) | Where-Object { $_.Name -eq "qlport_down_retry" }).Value -ne "60") { $FCDownRetry = "Wrong" }
        }
    }

    if ($BuildCheck -eq "Wrong" `
     -or $ProperInfoCheck -eq "Wrong" `
     -or $FQDN -eq "Wrong" `
     -or $TimeServers -eq "Wrong" `
     -or $TimePolicy -eq "Wrong" `
     -or $SNMPState -eq "Wrong" `
     -or $SNMPPolicy -eq "Wrong" `
     -or $DomainName -eq "Wrong" `
     -or $SearchDomain -eq "Wrong" `
     -or $VMKernelGateway -eq "Wrong" `
     -or $DNS -eq "Wrong" `
     -or $PowerPolicySetting -eq "Wrong" `
     -or $AlarmActions -eq "Wrong" `
     -or $StandardSwitchCheck -eq "Wrong" `
     -or ($DistributedSwitchCheck1 -eq "Wrong" -or $DistributedSwitchCheck2 -eq "Wrong") `
     -or $VAAIConfig1Check -eq "Wrong" `
     -or $VAAIConfig1Check -eq "Wrong" `
     -or $VAAIConfig1Check -eq "Wrong" `
     -or $DefaultPSP -eq "Wrong" `
     -or $StorageArrayTypeCheck -eq "Wrong" `
     -or $iSCSIQueueDepthCheck -eq "Wrong" `
     -or $iSCSILoginTimeoutCheck -eq "Wrong" `
     -or $FCMaxQueueDepth -eq "Wrong" `
     -or $FCLoginRetryCount -eq "Wrong" `
     -or $FCDownRetry -eq "Wrong")
     {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "$($ESXHost.Name) has a config problem."
        $hostfails += New-Object PSObject -Property @{
            HostName = $ESXHost.Name
            BuildCheck = $BuildCheck
            ProperInfoCheck = $ProperInfoCheck
            FQDN = $FQDN
            TimeServers = $TimeServers
            TimePolicy = $TimePolicy
            SNMPState = $SNMPState
            SNMPPolicy = $SNMPPolicy
            DomainName = $DomainName
            SearchDomain = $SearchDomain
            VMKernelGateway = $VMKernelGateway
            DNS = $DNS
            PowerPolicySetting = $PowerPolicySetting
            AlarmActions = $AlarmActions
            StandardSwitchCheck = $StandardSwitchCheck
            DistributedSwitchCheck1 = $DistributedSwitchCheck1
            DistributedSwitchCheck2 = $DistributedSwitchCheck2
            VAAIConfig1Check = $VAAIConfig1Check
            VAAIConfig2Check = $VAAIConfig2Check
            VAAIConfig3Check = $VAAIConfig3Check
            DefaultPSP = $DefaultPSP
            StorageArrayTypeCheck = $StorageArrayTypeCheck
            iSCSIQueueDepthCheck = $iSCSIQueueDepthCheck
            iSCSILoginTimeoutCheck = $iSCSILoginTimeoutCheck
            FCMaxQueueDepth = $FCMaxQueueDepth
            FCLoginRetryCount = $FCLoginRetryCount
            FCDownRetry = $FCDownRetry
        }
     }

    Clear-Variable BuildCheck,ProperInfoCheck,FQDN,TimeServers,TimePolicy,SNMPState,SNMPPolicy,DomainName,SearchDomain,VMKernelGateway,DNS,PowerPolicySetting,AlarmActions,StandardSwitchCheck,DistributedSwitchCheck1,DistributedSwitchCheck2,VAAIConfig1Check,VAAIConfig2Check,VAAIConfig3Check,DefaultPSP,StorageArrayTypeCheck,iSCSIQueueDepthCheck,iSCSILoginTimeoutCheck,FCMaxQueueDepth,FCLoginRetryCount,FCDownRetry -ErrorAction Ignore
}

if ($hostfails.Count -gt 0)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing improperly configured clusters and building the email body..."
    $EmailBody = "The following hosts are misconfigured and their incorrect configuration settings are listed.`r`n`r`n"

    foreach ($hostfail in $hostfails)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding $($hostfail.HostName) to the email..."
        $EmailBody += "Host: $($hostfail.HostName)`r`n"

        if ($hostfail.BuildCheck -eq "Wrong") { $EmailBody += "Incorrect build number.`r`n" }
        if ($hostfail.ProperInfoCheck -eq "Wrong") { $EmailBody += "Host is in a cluster that does not have info in the data file. This will lead to false positives in the config checks and should be corrected ASAP.`r`n" }
        if ($hostfail.FQDN -eq "Wrong") { $EmailBody += "Incorrect FQDN.`r`n" }
        if ($hostfail.TimeServers -eq "Wrong") { $EmailBody += "Incorrect time servers.`r`n" }
        if ($hostfail.TimePolicy -eq "Wrong") { $EmailBody += "NTP Service not set to start with host.`r`n" }
        if ($hostfail.SNMPState -eq "Wrong") { $EmailBody += "SNMP is running.`r`n" }
        if ($hostfail.SNMPPolicy -eq "Wrong") { $EmailBody += "SNMP is set to start with the host.`r`n" }
        if ($hostfail.DomainName -eq "Wrong") { $EmailBody += "Incorrect domain name.`r`n" }
        if ($hostfail.SearchDomain -eq "Wrong") { $EmailBody += "Incorrect search domain.`r`n" }
        if ($hostfail.VMKernelGateway -eq "Wrong") { $EmailBody += "MGMT kernel adapter gateway incorrect.`r`n" }
        if ($hostfail.DNS -eq "Wrong") { $EmailBody += "Incorrect DNS servers.`r`n" }
        if ($hostfail.PowerPolicySetting -eq "Wrong") { $EmailBody += "Incorrect power policy setting.`r`n" }
        if ($hostfail.AlarmActions -eq "Wrong") { $EmailBody += "Alarm actions are disabled.`r`n" }
        if ($hostfail.StandardSwitchCheck -eq "Wrong") { $EmailBody += "There is a standard switch on this host with physical NICs attached to it.`r`n" }
        if ($hostfail.DistributedSwitchCheck1 -eq "Wrong") { $EmailBody += "Host is not joined to a distributed switch.`r`n" }
        if ($hostfail.DistributedSwitchCheck2 -eq "Wrong") { $EmailBody += "There is a vDS that does not have at least 2 physical NICs.`r`n" }
        if ($hostfail.VAAIConfig1Check -eq "Wrong") { $EmailBody += "HardwareAcceleratedMove setting is not correct.`r`n" }
        if ($hostfail.VAAIConfig2Check -eq "Wrong") { $EmailBody += "HardwareAcceleratedInit setting is not correct.`r`n" }
        if ($hostfail.VAAIConfig3Check -eq "Wrong") { $EmailBody += "HardwareAcceleratedLocking setting is not correct.`r`n" }
        if ($hostfail.DefaultPSP -eq "Wrong") { $EmailBody += "Default Path Selection Policy is incorrect.`r`n" }
        if ($hostfail.StorageArrayTypeCheck -eq "Wrong") { $EmailBody += "Host has Compellent volumes not set to use the correct Storage Array Type.`r`n" }
        if ($hostfail.iSCSIQueueDepthCheck -eq "Wrong") { $EmailBody += "iSCSI queue depth is incorrect.`r`n" }
        if ($hostfail.iSCSILoginTimeoutCheck -eq "Wrong") { $EmailBody += "iSCSI login timeout is incorrect.`r`n" }
        if ($hostfail.FCMaxQueueDepth -eq "Wrong") { $EmailBody += "FC/FCoE Max Queue Depth is incorrect.`r`n" }
        if ($hostfail.FCLoginRetryCount -eq "Wrong") { $EmailBody += "FC/FCoE Login Retry Count is incorret.`r`n" }
        if ($hostfail.FCDownRetry -eq "Wrong") { $EmailBody += "FC/FCoE Down Retry is incorrect.`r`n" }

        $EmailBody += "`r`n"
    }

    $EmailBody += "Script executed on $($env:computername)."

    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "VirtualComplianceCheck found config problems in $vCenter host checks" -body $EmailBody
}



###############
# vDS Checks
###############
$vdsfails = @()
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking cluster configurations..."
foreach ($DS in $ESXvDS)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing $($DS.Name)..."

    if ($DS.Mtu -ne 1500)
    {
        $vdsfails += New-Object PSObject -Property @{
            SwitchName = $DS.Name
            MTU = "Wrong"
        }
    }
}

if ($vdsfails.Count -gt 0)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing improperly configured distributed switches and building the email body..."
    $EmailBody = "The following distributed switches are misconfigured and their incorrect configuration settings are listed.`r`n`r`n"

    foreach ($vdsfail in $vdsfails)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding $($vdsfail.Name) to the email..."
        $EmailBody += "Switch: $($vdsfail.Name)`r`n"

        if ($vdsfail.MTU -eq "Wrong") { $EmailBody += "MTU is not 1500." }
    }
    $EmailBody += "Script executed on $($env:computername)."

    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "VirtualComplianceCheck found config problems in $vCenter vDS checks" -body $EmailBody
}
