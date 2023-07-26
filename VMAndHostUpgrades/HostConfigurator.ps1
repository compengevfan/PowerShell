[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter,
    [Parameter()] [string] $HostToCheck
)
 
$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
 
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
 
#$ErrorActionPreference = "SilentlyContinue"
 
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
Connect-DFvCenter -vCenter $vCenter

. .\Functions\function_Get-AlarmActionState.ps1
. .\Functions\function_Set-AlarmActionState.ps1

if ($HostToCheck -eq "") { $HostToCheck = Read-Host "Please enter the name of the host to configure" }
$HostToConfig = Get-VMHost $HostToCheck

if ($HostToConfig -eq $null -or $HostToConfig -eq "") { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Host does not exist in $vCenter. Script Exiting."; exit }

$CompellentAttached = Read-Host "Is this host connected to a Compellent array (y/n)?"

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting host mapping information from data file..."
$DataFromFile = Import-Csv .\HostConfigurator-Data.csv

$ParentCluster = $HostToConfig.Parent.Name

$ProperInfo = $DataFromFile | ? { $_.Cluster -eq $ParentCluster }

##################
#Verify ESXi build number. If wrong, exit.
##################
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking ESXi build number..."
$OSInfo = Get-View -ViewType HostSystem -Filter @{"Name"=$($HostToConfig).Name} -Property Name,Config.Product | ForEach-Object {$_.Name, $_.Config.Product}
if ($OSInfo.Build -eq 7388607)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "ESXi build number is correct..."
}
else
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "ESXi build number is incorrect!!! Please install the proper version of ESXi and try again. Script Exiting!!!"
    exit
}

##################
#Verify host name is FQDN. If wrong, exit.
##################
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying hostname includes domain name..."
if ($HostToConfig.Name -like "*$($ProperInfo.Domain)")
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Hostname contains the proper domain."
}
else
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Hostname does not contain the proper domain!!! Please correct the hostname and try again. Script Exiting!!!"
    exit
}

##################
#NTP Servers
##################
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting the list of NTP servers..."
$NTPServers = Get-VMHostNtpServer $HostToConfig
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting the NTP Daemon settings..."	
$ntp = Get-VmHostService -VMhost $HostToConfig | Where-Object {$_.Key -eq 'ntpd'}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking the NTP server config..."
#Check the NTP Servers on the host.
if ($NTPServers -contains "ntp-iad-01.fanatics.corp" -and $NTPServers -contains "ntp-iad-02.fanatics.corp" -and $NTPServers -contains "ntp-dfw-01.fanatics.corp" -and $NTPServers -contains "ntp-dfw-02.fanatics.corp" -and $NTPServers.Count -eq 4)
{
	Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "NTP Server config is correct..."
}
else #If the NTP servers are not correct, fix them.
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "NTP Server config is incorrect..."
	if ($ntp.Running -eq "True")
	{
		Stop-VMHostService $ntp -Confirm:$false | Out-Null
	}
	foreach ($NTPServer in $NTPServers)
	{
		Remove-VMHostNtpServer -NtpServer $NTPServer -VMHost $HostToConfig -Confirm:$false | Out-Null
	}
	Add-VmHostNtpServer -NtpServer "ntp-iad-01.fanatics.corp" -VmHost $HostToConfig | Out-Null
	Add-VmHostNtpServer -NtpServer "ntp-iad-02.fanatics.corp" -VmHost $HostToConfig | Out-Null
    Add-VmHostNtpServer -NtpServer "ntp-dfw-01.fanatics.corp" -VmHost $HostToConfig | Out-Null
    Add-VmHostNtpServer -NtpServer "ntp-dfw-02.fanatics.corp" -VmHost $HostToConfig | Out-Null
	Start-VMHostService $ntp -Confirm:$false | Out-Null
    $VerifyNTP = Get-VMHostNtpServer $HostToConfig
    if ($VerifyNTP[0] -eq "") { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Due to a bug in PowerCLI, there is an extra, blank NTP server in the time settings that can't be removed via script. Please remove this manually and restart the NTP service." }
    else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "NTP Server config fixed." }
}
	
#Check to see if the NTP service is set to start and stop with the host.
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifing NTP Daemon set to start with host..."
if ($ntp.Policy -ne "on")
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Updating Daemon startup policy..."
	Set-VMHostService -HostService $ntp -Policy "on"
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Daemon startup policy updated."
}
else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Daemon startup policy is correct." }

##################
#SNMP service.
##################
#Ensure service is not runnig and not configured to start with host.
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting the SNMP Daemon settings..."
$snmp = Get-VMHostService -VMHost $HostToConfig | Where-Object {$_.Key -eq 'snmpd'}
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking to see if the SNMP service is running..."
if ($snmp.Running -eq "True")
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Stopping SNMP service..."
    Stop-VMHostService $snmp -Confirm:$false | Out-Null
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "SNMP service has been stopped."
}
else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "SNMP service is not running." }

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking to see if the SNMP service is set to start with host..."
if ($snmp.Policy -eq "On")
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Updating Daemon startup policy..."
    Set-VMHostService -HostService $snmp -Policy "off" | Out-Null
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Daemon startup policy updated."
}
else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Daemon startup policy is correct." }

##################
#Domain, domain look up, DNS Servers and Gateway is correct
##################
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting Domain, domain look up, DNS Servers and Gateway information..."
$Network = Get-VMHostNetwork -VMHost $HostToCheck

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking domain name..."
if ($Network.DomainName -ne $($ProperInfo.Domain))
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Domain name is incorrect..."
	Set-VMHostNetwork $Network -DomainName $($ProperInfo.Domain) | Out-Null
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Domain has been updated."
}
else
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Domain name is correct."
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking search domain..."
if ($Network.SearchDomain -ne $($ProperInfo.Domain))
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Search domain is incorrect..."
	Set-VMHostNetwork $Network -SearchDomain $($ProperInfo.Domain) | Out-Null
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Search domain has been updated."
}
else
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Search domain is correct."
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking Gateway"
if ($Network.VMKernelGateway -ne $($ProperInfo.Gateway))
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Gateway is incorrect..."
	Set-VMHostNetwork $Network -VMKernelGateway $($ProperInfo.Gateway) | Out-Null
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Gateway has been updated."
}
else
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Gateway is correct."
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking DNS Servers"
if ($Network.DnsAddress -contains $($ProperInfo.DNS1) -and $Network.DnsAddress -contains $($ProperInfo.DNS2) -and $Network.DnsAddress.Count -eq 2)
{
	Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "DNS servers are correct."
}
else #If the DNS servers are not correct, fix them.
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "DNS servers are incorrect..."
	Set-VMHostNetwork $Network -DnsAddress @("$($ProperInfo.DNS1)","$($ProperInfo.DNS2)") | Out-Null
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "DNS servers have been updated."
}

##################
#Check power management policy
##################
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking power management policy..."
$vmhostview = Get-View -ViewType Hostsystem -Filter @{"Name"=$($HostToConfig).Name} -Property ConfigManager.PowerSystem
$powerpolicy = Get-View $vmhostview.ConfigManager.PowerSystem
if ($($powerpolicy.Info.CurrentPolicy.Key) -eq 1)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Power management policy is set to 'High Performance'."
}
else
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Power management policy is incorrect..."
    $powerpolicy.ConfigurePowerPolicy(1)
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Power management policy has been updated."
}

##################
#Check alarm actions
##################
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking alarm action setting..."
$AlarmActionState = Get-AlarmActionState -Entity $HostToConfig -Recurse:$false
if ($($AlarmActionState.'Alarm actions enabled') -eq "True")
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Alarm actions are enabled."
}
else
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Alarm actions are disabled..."
    Set-AlarmActionState -Entity $HostToConfig -Enabled:$true -Recurse:$false
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Alarm actions enabled."
}

##################
#Check virtual switch config excluding "voice" clusters
##################
if ($ParentCluster -like "*Voice")
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Host is a member of a voice cluster. Skipping switch config checks."
}
else
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining standard switch configuration..."
    $StandardSwitches = Get-VirtualSwitch -VMHost $HostToConfig -Standard
    if ($StandardSwitches.Nic.Count -gt 0)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "There is a standard switch on this host with physical NICs attached to it!!!"
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "This MUST be corrected before putting the host in production!!!"
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "To prevent loss of connectivity, this script will not correct this automatically!!!"
    }
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining distributed switch configuration..."
    $DistributedSwitches = Get-VDSwitch -VMHost $HostToConfig
    if ($DistributedSwitches -eq $null -or $DistributedSwitches -eq "")
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "$HostToConfig is not joined to a distributed switch!!!"
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "This MUST be corrected before putting the host in production!!!"
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "To prevent loss of connectivity, this script will not correct this automatically!!!"
    }
    else
    {
        foreach ($DistributedSwitch in $DistributedSwitches)
        {
            $Nics = Get-VMHostNetworkAdapter -VMHost $HostToConfig -DistributedSwitch $DistributedSwitch -Physical | Sort-Object name
            if ($Nics.Count -lt 2)
            {
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Distributed switch '$DistributedSwitch' does not have at least 2 physical NICs!!!"
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "This MUST be corrected before putting the host in production!!!"
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "To prevent loss of connectivity, this script will not correct this automatically!!!"
            }
            else
            {
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Distributed switch '$DistributedSwitch' has at least 2 physical NICs."
            }
        }
    }
}

##################
#VAAI, ALUA, iSCSI/FC Config Check
##################
if ($CompellentAttached -eq "y")
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Host is attached to Compellent, checking and configuring VAAI and ALUA settings..."
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking HardwareAcceleratedMove setting..."
    $VAAIConfig = Get-AdvancedSetting -Entity $HostToConfig -Name DataMover.HardwareAcceleratedMove
    if ($VAAIConfig.Value -ne 1)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "HardwareAcceleratedMove is incorrect..."
	    $VAAIConfig | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null
    }
    else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "HardwareAcceleratedMove setting is correct." }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking HardwareAcceleratedInit setting..."
    $VAAIConfig = Get-AdvancedSetting -Entity $HostToConfig -Name DataMover.HardwareAcceleratedInit
    if ($VAAIConfig.Value -ne 1)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "HardwareAcceleratedInit is incorrect..."
	    $VAAIConfig | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null
    }
    else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "HardwareAcceleratedInit setting is correct." }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking HardwareAcceleratedLocking setting..."
    $VAAIConfig = Get-AdvancedSetting -Entity $HostToConfig -Name VMFS3.HardwareAcceleratedLocking
    if ($VAAIConfig.Value -ne 1)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "HardwareAcceleratedLocking is incorrect..."
	    $VAAIConfig | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null
    }
    else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "HardwareAcceleratedLocking setting is correct." }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Connecting to the the host's CLI..."
    $esxcli = Get-EsxCli -V2 -VMHost $HostToConfig

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking default path selection policy setting for SATP 'VMW_SATP_ALUA'..."
    if ($($esxcli.storage.nmp.satp.list.Invoke() | Where-Object {$_.Name -eq "VMW_SATP_ALUA"}).DefaultPSP -ne "VMW_PSP_RR")
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Default path selection policy is incorrect..."
        $esxcli.storage.nmp.satp.set.Invoke(@{defaultpsp="VMW_PSP_RR";satp="VMW_SATP_ALUA"}) | Out-Null
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Default path selection policy updated."
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "!!!THIS CHANGE REQUIRES A HOST REBOOT!!!"
    }
    else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Path Selection Policy setting is correct." }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking Compellent volume Storage Array Type..."
    $CompellentVolumeCheck = $esxcli.storage.nmp.device.list.Invoke() | Where-Object { $_.DeviceDisplayName -like "COMPELNT*" -and $_.StorageArrayType -ne "VMW_SATP_ALUA" }
    if ($CompellentVolumeCheck -ne $null)
    {
        foreach($Volume in $CompellentVolumeCheck)
        {
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Setting Storage Array Type for volume $($Volume.Device)..."
            $esxcli.storage.nmp.device.set.Invoke(@{device=$($Volume.Device);psp="VMW_SATP_ALUA"})
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Storage Array Type set."
        }
    }
    else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "All Compellent volumes are set to the correct Storage Array Type." }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking host for Software iSCSI adapter..."
    if ($esxcli.iscsi.adapter.list.Invoke().Description -eq "iSCSI Software Adapter")
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Software iSCSI adapter found...Obtaining adapter name..."
        $iSCSIAdapterName = $($esxcli.iscsi.adapter.list.Invoke() | Where-Object { $_.Description -eq "iSCSI Software Adapter" }).Adapter

        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking iSCSI module queue depth..."
        $iSCSIQueueDepth = $($($esxcli.system.module.parameters.list.Invoke(@{module="iscsi_vmk"})) | Where-Object { $_.Name -eq "iscsivmk_LunQDepth" }).Value
        if ($iSCSIQueueDepth -eq $null -or $iSCSIQueueDepth -ne "255")
        {
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Setting iSCSI module queue depth..."
            $esxcli.system.module.parameters.set.Invoke(@{module="iscsi_vmk";parameterstring="iscsivmk_LunQDepth=255"})
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "!!!THIS CHANGE REQUIRES A HOST REBOOT!!!"
        }
        else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "iSCSI Queue Depth is correct."}

        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking iSCSI login timeout..."
        $iSCSILoginTimeout = $($esxcli.iscsi.adapter.param.get.Invoke(@{adapter=$iSCSIAdapterName}) | Where-Object { $_.Name -eq "LoginTimeout" }).Current
        if ($iSCSILoginTimeout -eq $null -or $iSCSILoginTimeout -ne "5")
        {
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Setting iSCSI login timeout..."
            $esxcli.iscsi.adapter.param.set.Invoke(@{adapter=$iSCSIAdapterName;key="LoginTimeout";value=5})
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "!!!THIS CHANGE REQUIRES A HOST REBOOT!!!"
        }
        else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "iSCSI Login Timeout is correct." }
    }
    else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Software iSCSI adapter not found." }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking host for QLogic FC/FCoE adapters..."
    if ($($esxcli.system.module.list.Invoke() | Where-Object { $_.Name -like "ql*" -or $_.Name -eq "qedentv" }).Count -ge 1)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "FC/FCoE adapter(s) found..."
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting QLogic FC/FCoE queue depth and timeouts..."
        $esxcli.system.module.parameters.set.Invoke(@{module="qlnativefc";parameterstring="ql2xmaxqdepth=255 ql2xloginretrycount=60 qlport_down_retry=60"}) | Out-Null
    }
    else 
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "QLogic FC/FCoE adapters not found!!!"
    }
}