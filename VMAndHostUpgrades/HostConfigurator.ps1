[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter,
    [Parameter()] [string] $HostToCheck
)
 
$ScriptPath = $PSScriptRoot
cd $ScriptPath
 
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
Connect-vCenter -vCenter $vCenter

. .\Functions\function_Get-AlarmActionState.ps1
. .\Functions\function_Set-AlarmActionState.ps1

if ($HostToCheck -eq "") { $HostToCheck = Read-Host "Please enter the name of the host to configure" }
$HostToConfig = Get-VMHost $HostToCheck

if ($HostToConfig -eq $null -or $HostToConfig -eq "") { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Host does not exist in $vCenter. Script Exiting."; exit }

$CompellentAttached = Read-Host "Is this host connected to a Compellent array (y/n)?"

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting host mapping information from data file..."
$DataFromFile = Import-Csv .\HostConfigurator-Data.csv

$ParentCluster = $HostToConfig.Parent.Name

$ProperInfo = $DataFromFile | ? { $_.Cluster -eq $ParentCluster }

##################
#Verify ESXi build number. If wrong, exit.
##################
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking ESXi build number..."
$OSInfo = Get-View -ViewType HostSystem -Filter @{"Name"=$($HostToConfig).Name} -Property Name,Config.Product | foreach {$_.Name, $_.Config.Product}
if ($OSInfo.Build -eq 7388607)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "ESXi build number is correct..."
}
else
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "ESXi build number is incorrect!!! Please install the proper version of ESXi and try again. Script Exiting!!!"
    exit
}

##################
#Verify host name is FQDN. If wrong, exit.
##################
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying hostname includes domain name..."
if ($HostToConfig.Name -like "*$($ProperInfo.Domain)")
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Hostname contains the proper domain."
}
else
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Hostname does not contain the proper domain!!! Please correct the hostname and try again. Script Exiting!!!"
    exit
}

##################
#NTP Servers
##################
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting the list of NTP servers..."
$NTPServers = Get-VMHostNtpServer $HostToConfig
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting the NTP Daemon settings..."	
$ntp = Get-VmHostService -VMhost $HostToConfig | Where {$_.Key -eq 'ntpd'}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking the NTP server config..."
#Check the NTP Servers on the host.
if ($NTPServers -contains "ntp-iad-01.fanatics.corp" -and $NTPServers -contains "ntp-iad-02.fanatics.corp" -and $NTPServers -contains "ntp-dfw-01.fanatics.corp" -and $NTPServers -contains "ntp-dfw-02.fanatics.corp" -and $NTPServers.Count -eq 4)
{
	DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "NTP Server config is correct..."
}
else #If the NTP servers are not correct, fix them.
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "NTP Server config is incorrect..."
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
    if ($VerifyNTP[0] -eq "") { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Due to a bug in PowerCLI, there is an extra, blank NTP server in the time settings that can't be removed via script. Please remove this manually and restart the NTP service." }
    else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "NTP Server config fixed." }
}
	
#Check to see if the NTP service is set to start and stop with the host.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifing NTP Daemon set to start with host..."
if ($ntp.Policy -ne "on")
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Updating Daemon startup policy..."
	Set-VMHostService -HostService $ntp -Policy "on"
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Daemon startup policy updated."
}
else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Daemon startup policy is correct." }

##################
#SNMP service.
##################
#Ensure service is not runnig and not configured to start with host.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting the SNMP Daemon settings..."
$snmp = Get-VMHostService -VMHost $HostToConfig | where {$_.Key -eq 'snmpd'}
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking to see if the SNMP service is running..."
if ($snmp.Running -eq "True")
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Stopping SNMP service..."
    Stop-VMHostService $snmp -Confirm:$false | Out-Null
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "SNMP service has been stopped."
}
else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "SNMP service is not running." }

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking to see if the SNMP service is set to start with host..."
if ($snmp.Policy -eq "On")
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Updating Daemon startup policy..."
    Set-VMHostService -HostService $snmp -Policy "off" | Out-Null
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Daemon startup policy updated."
}
else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Daemon startup policy is correct." }

##################
#Domain, domain look up, DNS Servers and Gateway is correct
##################
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting Domain, domain look up, DNS Servers and Gateway information..."
$Network = Get-VMHostNetwork -VMHost $HostToCheck

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking domain name..."
if ($Network.DomainName -ne $($ProperInfo.Domain))
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Domain name is incorrect..."
	Set-VMHostNetwork $Network -DomainName $($ProperInfo.Domain) | Out-Null
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Domain has been updated."
}
else
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Domain name is correct."
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking search domain..."
if ($Network.SearchDomain -ne $($ProperInfo.Domain))
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Search domain is incorrect..."
	Set-VMHostNetwork $Network -SearchDomain $($ProperInfo.Domain) | Out-Null
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Search domain has been updated."
}
else
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Search domain is correct."
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking Gateway"
if ($Network.VMKernelGateway -ne $($ProperInfo.Gateway))
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Gateway is incorrect..."
	Set-VMHostNetwork $Network -VMKernelGateway $($ProperInfo.Gateway) | Out-Null
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Gateway has been updated."
}
else
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Gateway is correct."
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking DNS Servers"
if ($Network.DnsAddress -contains $($ProperInfo.DNS1) -and $Network.DnsAddress -contains $($ProperInfo.DNS2) -and $Network.DnsAddress.Count -eq 2)
{
	DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "DNS servers are correct."
}
else #If the DNS servers are not correct, fix them.
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "DNS servers are incorrect..."
	Set-VMHostNetwork $Network -DnsAddress @("$($ProperInfo.DNS1)","$($ProperInfo.DNS2)") | Out-Null
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "DNS servers have been updated."
}

##################
#Check power management policy
##################
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking power management policy..."
$vmhostview = Get-View -ViewType Hostsystem -Filter @{"Name"=$($HostToConfig).Name} -Property ConfigManager.PowerSystem
$powerpolicy = Get-View $vmhostview.ConfigManager.PowerSystem
if ($($powerpolicy.Info.CurrentPolicy.Key) -eq 1)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Power management policy is set to 'High Performance'."
}
else
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Power management policy is incorrect..."
    $powerpolicy.ConfigurePowerPolicy(1)
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Power management policy has been updated."
}

##################
#Check alarm actions
##################
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking alarm action setting..."
$AlarmActionState = Get-AlarmActionState -Entity $HostToConfig -Recurse:$false
if ($($AlarmActionState.'Alarm actions enabled') -eq "True")
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Alarm actions are enabled."
}
else
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Alarm actions are disabled..."
    Set-AlarmActionState -Entity $HostToConfig -Enabled:$true -Recurse:$false
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Alarm actions enabled."
}

##################
#Check virtual switch config excluding "voice" clusters
##################
if ($ParentCluster -like "*Voice")
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Host is a member of a voice cluster. Skipping switch config checks."
}
else
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining standard switch configuration..."
    $StandardSwitches = Get-VirtualSwitch -VMHost $HostToConfig -Standard
    if ($StandardSwitches.Nic.Count -gt 0)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "There is a standard switch on this host with physical NICs attached to it!!!"
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "This MUST be corrected before putting the host in production!!!"
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "To prevent loss of connectivity, this script will not correct this automatically!!!"
    }
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining distributed switch configuration..."
    $DistributedSwitches = Get-VDSwitch -VMHost $HostToConfig
    if ($DistributedSwitches -eq $null -or $DistributedSwitches -eq "")
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "$HostToConfig is not joined to a distributed switch!!!"
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "This MUST be corrected before putting the host in production!!!"
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "To prevent loss of connectivity, this script will not correct this automatically!!!"
    }
    else
    {
        foreach ($DistributedSwitch in $DistributedSwitches)
        {
            $Nics = Get-VMHostNetworkAdapter -VMHost $HostToConfig -DistributedSwitch $DistributedSwitch -Physical | sort name
            if ($Nics.Count -lt 2)
            {
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Distributed switch '$DistributedSwitch' does not have at least 2 physical NICs!!!"
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "This MUST be corrected before putting the host in production!!!"
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "To prevent loss of connectivity, this script will not correct this automatically!!!"
            }
            else
            {
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Distributed switch '$DistributedSwitch' has at least 2 physical NICs."
            }
        }
    }
}

##################
#VAAI and ALUA Config Check
##################
if ($CompellentAttached -eq "y")
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Host is attached to Compellent, checking and configuring VAAI and ALUA settings..."
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking HardwareAcceleratedMove setting..."
    $VAAIConfig = Get-AdvancedSetting -Entity $HostToConfig -Name DataMover.HardwareAcceleratedMove
    if ($VAAIConfig.Value -ne 1)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "HardwareAcceleratedMove is incorrect..."
	    $VAAIConfig | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null
    }
    else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "HardwareAcceleratedMove setting is correct." }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking HardwareAcceleratedInit setting..."
    $VAAIConfig = Get-AdvancedSetting -Entity $HostToConfig -Name DataMover.HardwareAcceleratedInit
    if ($VAAIConfig.Value -ne 1)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "HardwareAcceleratedInit is incorrect..."
	    $VAAIConfig | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null
    }
    else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "HardwareAcceleratedInit setting is correct." }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking HardwareAcceleratedLocking setting..."
    $VAAIConfig = Get-AdvancedSetting -Entity $HostToConfig -Name VMFS3.HardwareAcceleratedLocking
    if ($VAAIConfig.Value -ne 1)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "HardwareAcceleratedLocking is incorrect..."
	    $VAAIConfig | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null
    }
    else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "HardwareAcceleratedLocking setting is correct." }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Connecting to the the host's CLI..."
    $esxcli = Get-EsxCli -V2 -VMHost $HostToConfig

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking default path selection policy setting for SATP 'VMW_SATP_ALUA'..."
    if ($($esxcli.storage.nmp.satp.list.Invoke() | where {$_.Name -eq "VMW_SATP_ALUA"}).DefaultPSP -ne "VMW_PSP_RR")
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Default path selection policy is incorrect..."
        $esxcli.storage.nmp.satp.set.Invoke(@{defaultpsp="VMW_PSP_RR";satp="VMW_SATP_ALUA"}) | Out-Null
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Default path selection policy updated."
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "!!!THIS CHANGE REQUIRES A HOST REBOOT!!!"
    }
    else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Path Selection Policy setting is correct." }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking Compellent volume Storage Array Type..."
    $CompellentVolumeCheck = $esxcli.storage.nmp.device.list.Invoke() | ? { $_.DeviceDisplayName -like "COMPELNT*" -and $_.StorageArrayType -ne "VMW_SATP_ALUA" }
    if ($CompellentVolumeCheck -ne $null)
    {
        foreach($Volume in $CompellentVolumeCheck)
        {
            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Setting Storage Array Type for volume $($Volume.Device)..."
            $esxcli.storage.nmp.device.set.Invoke(@{device=$($Volume.Device);psp="VMW_SATP_ALUA"})
            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Storage Array Type set."
        }
    }
    else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "All Compellent volumes are set to the correct Storage Array Type." }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking host for Software iSCSI adapter..."
    if ($esxcli.iscsi.adapter.list.Invoke().Description -eq "iSCSI Software Adapter")
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Software iSCSI adapter found...Obtaining adapter name..."
        $iSCSIAdapterName = $($esxcli.iscsi.adapter.list.Invoke() | Where-Object { $_.Description -eq "iSCSI Software Adapter" }).Adapter

        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking iSCSI module queue depth..."
        $iSCSIQueueDepth = $($($esxcli.system.module.parameters.list.Invoke(@{module="iscsi_vmk"})) | Where-Object { $_.Name -eq "iscsivmk_LunQDepth" }).Value
        if ($iSCSIQueueDepth -eq $null -or $iSCSIQueueDepth -ne "255")
        {
            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Setting iSCSI module queue depth..."
            $esxcli.system.module.parameters.set.Invoke(@{module="iscsi_vmk";parameterstring="iscsivmk_LunQDepth=255"})
            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "!!!THIS CHANGE REQUIRES A HOST REBOOT!!!"
        }
        else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "iSCSI Queue Depth is correct."}

        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking iSCSI login timeout..."
        $iSCSILoginTimeout = $($esxcli.iscsi.adapter.param.get.Invoke(@{adapter=$iSCSIAdapterName}) | Where-Object { $_.Name -eq "LoginTimeout" }).Current
        if ($iSCSILoginTimeout -eq $null -or $iSCSILoginTimeout -ne "5")
        {
            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Setting iSCSI login timeout..."
            $esxcli.iscsi.adapter.param.set.Invoke(@{adapter=$iSCSIAdapterName;key="LoginTimeout";value=5})
            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "!!!THIS CHANGE REQUIRES A HOST REBOOT!!!"
        }
        else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "iSCSI Login Timeout is correct." }
    }
    else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Software iSCSI adapter not found." }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking host for FC/FCoE adapters..."
    if ($($HosttoConfig | Get-VMHostHba | Where-Object { $_.Type -eq "FibreChannel" -and $_.Status -eq "Online" }).Count -ge 1)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "FC/FCoE adapter(s) found..."
    }
}
