[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter,
    [Parameter()] [string] $HostToCheck
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath

. .\Functions\function_Check-PowerCLI.ps1
. .\Functions\function_Connect-vCenter.ps1
. .\Functions\Function_DoLogging.ps1
. .\Functions\function_Get-AlarmActionState.ps1
. .\Functions\function_Set-AlarmActionState.ps1

Check-PowerCLI

##################
#System/Global Variables
##################
$ErrorActionPreference = "SilentlyContinue"
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

Connect-vCenter -vCenter $vCenter

if ($HostToCheck -eq "") { $HostToCheck = Read-Host "Please enter the name of the host to configure" }
$HostToConfig = Get-VMHost $HostToCheck

if ($HostToConfig -eq $null -or $HostToConfig -eq "") { DoLogging -LogType Err -LogString "Host does not exist in $vCenter. Script Exiting."; exit }

$CompellentAttached = Read-Host "Is this host connected to a Compellent array (y/n)?"

DoLogging -LogType Info -LogString "Getting host mapping information from data file..."
$DataFromFile = Import-Csv .\HostConfigurator-Data.csv

$ParentCluster = $HostToConfig.Parent.Name

$ProperInfo = $DataFromFile | ? { $_.Cluster -eq $ParentCluster }

##################
#Verify ESXi build number. If wrong, exit.
##################
DoLogging -LogType Info -LogString "Checking ESXi build number..."
$OSInfo = Get-View -ViewType HostSystem -Filter @{"Name"=$($HostToConfig).Name} -Property Name,Config.Product | foreach {$_.Name, $_.Config.Product}
if ($OSInfo.Build -eq 7388607)
{
    DoLogging -LogType Info -LogString "ESXi build number is correct..."
}
else
{
    DoLogging -LogType Err -LogString "ESXi build number is incorrect!!! Please install the proper version of ESXi and try again. Script Exiting!!!"
    exit
}

##################
#Verify host name is FQDN. If wrong, exit.
##################
DoLogging -LogType Info -LogString "Verifying hostname includes domain name..."
if ($HostToConfig.Name -like "*$($ProperInfo.Domain)")
{
    DoLogging -LogType Succ -LogString "Hostname contains the proper domain."
}
else
{
    DoLogging -LogType Err -LogString "Hostname does not contain the proper domain!!! Please correct the hostname and try again. Script Exiting!!!"
    exit
}

##################
#NTP Servers
##################
DoLogging -LogType Info -LogString "Getting the list of NTP servers..."
$NTPServers = Get-VMHostNtpServer $HostToConfig
DoLogging -LogType Info -LogString "Getting the NTP Daemon settings..."	
$ntp = Get-VmHostService -VMhost $HostToConfig | Where {$_.Key -eq 'ntpd'}

DoLogging -LogType Info -LogString "Checking the NTP server config..."
#Check the NTP Servers on the host.
if ($NTPServers -contains "ntp-iad-01.fanatics.corp" -and $NTPServers -contains "ntp-iad-02.fanatics.corp" -and $NTPServers -contains "ntp-dfw-01.fanatics.corp" -and $NTPServers -contains "ntp-dfw-02.fanatics.corp" -and $NTPServers.Count -eq 4)
{
	DoLogging -LogType Succ -LogString "NTP Server config is correct..."
}
else #If the NTP servers are not correct, fix them.
{
    DoLogging -LogType Warn -LogString "NTP Server config is incorrect..."
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
    if ($VerifyNTP[0] -eq "") { DoLogging -LogType Warn -LogString "Due to a bug in PowerCLI, there is an extra, blank NTP server in the time settings that can't be removed via script. Please remove this manually and restart the NTP service." }
    else { DoLogging -LogType Succ -LogString "NTP Server config fixed." }
}
	
#Check to see if the NTP service is set to start and stop with the host.
DoLogging -LogType Info -LogString "Verifing NTP Daemon set to start with host..."
if ($ntp.Policy -ne "on")
{
    DoLogging -LogType Warn -LogString "Updating Daemon startup policy..."
	Set-VMHostService -HostService $ntp -Policy "on"
    DoLogging -LogType Warn -LogString "Daemon startup policy updated."
}
else
{
    DoLogging -LogType Succ -LogString "Daemon startup policy is correct."
}

##################
#Domain, domain look up, DNS Servers and Gateway is correct
##################
DoLogging -LogType Info -LogString "Getting Domain, domain look up, DNS Servers and Gateway information..."
$Network = Get-VMHostNetwork -VMHost $HostToCheck

DoLogging -LogType Info -LogString "Checking domain name..."
if ($Network.DomainName -ne $($ProperInfo.Domain))
{
    DoLogging -LogType Warn -LogString "Domain name is incorrect..."
	Set-VMHostNetwork $Network -DomainName $($ProperInfo.Domain) | Out-Null
    DoLogging -LogType Succ -LogString "Domain has been updated."
}
else
{
    DoLogging -LogType Succ -LogString "Domain name is correct."
}

DoLogging -LogType Info -LogString "Checking search domain..."
if ($Network.SearchDomain -ne $($ProperInfo.Domain))
{
    DoLogging -LogType Warn -LogString "Search domain is incorrect..."
	Set-VMHostNetwork $Network -SearchDomain $($ProperInfo.Domain) | Out-Null
    DoLogging -LogType Succ -LogString "Search domain has been updated."
}
else
{
    DoLogging -LogType Succ -LogString "Search domain is correct."
}

DoLogging -LogType Info -LogString "Checking Gateway"
if ($Network.VMKernelGateway -ne $($ProperInfo.Gateway))
{
    DoLogging -LogType Warn -LogString "Gateway is incorrect..."
	Set-VMHostNetwork $Network -VMKernelGateway $($ProperInfo.Gateway) | Out-Null
    DoLogging -LogType Succ -LogString "Gateway has been updated."
}
else
{
    DoLogging -LogType Succ -LogString "Gateway is correct."
}

DoLogging -LogType Info -LogString "Checking DNS Servers"
if ($Network.DnsAddress -contains $($ProperInfo.DNS1) -and $Network.DnsAddress -contains $($ProperInfo.DNS2) -and $Network.DnsAddress.Count -eq 2)
{
	DoLogging -LogType Succ -LogString "DNS servers are correct."
}
else #If the DNS servers are not correct, fix them.
{
    DoLogging -LogType Warn -LogString "DNS servers are incorrect..."
	Set-VMHostNetwork $Network -DnsAddress @("$($ProperInfo.DNS1)","$($ProperInfo.DNS2)") | Out-Null
    DoLogging -LogType Warn -LogString "DNS servers have been updated."
}

##################
#Check power management policy
##################
DoLogging -LogType Info -LogString "Checking power management policy..."
$vmhostview = Get-View -ViewType Hostsystem -Filter @{"Name"=$($HostToConfig).Name} -Property ConfigManager.PowerSystem
$powerpolicy = Get-View $vmhostview.ConfigManager.PowerSystem
if ($($powerpolicy.Info.CurrentPolicy.Key) -eq 1)
{
    DoLogging -LogType Succ -LogString "Power management policy is set to 'High Performance'."
}
else
{
    DoLogging -LogType Warn -LogString "Power management policy is incorrect..."
    $powerpolicy.ConfigurePowerPolicy(1)
    DoLogging -LogType Succ -LogString "Power management policy has been updated."
}

##################
#Check alarm actions
##################
DoLogging -LogType Info -LogString "Checking alarm action setting..."
$AlarmActionState = Get-AlarmActionState -Entity $HostToConfig -Recurse:$false
if ($($AlarmActionState.'Alarm actions enabled') -eq "True")
{
    DoLogging -LogType Succ -LogString "Alarm actions are enabled."
}
else
{
    DoLogging -LogType Warn -LogString "Alarm actions are disabled..."
    Set-AlarmActionState -Entity $HostToConfig -Enabled:$true -Recurse:$false
    DoLogging -LogType Succ -LogString "Alarm actions enabled."
}

##################
#Check virtual switch config excluding "voice" clusters
##################
if ($ParentCluster -like "*Voice")
{
    DoLogging -LogType Info -LogString "Host is a member of a voice cluster. Skipping switch config checks."
}
else
{
    DoLogging -LogType Info -LogString "Obtaining standard switch configuration..."
    $StandardSwitches = Get-VirtualSwitch -VMHost $HostToConfig -Standard
    if ($StandardSwitches.Nic.Count -gt 0)
    {
        DoLogging -LogType Err -LogString "There is a standard switch on this host with physical NICs attached to it!!!"
        DoLogging -LogType Err -LogString "This MUST be corrected before putting the host in production!!!"
        DoLogging -LogType Err -LogString "To prevent loss of connectivity, this script will not correct this automatically!!!"
    }
    DoLogging -LogType Info -LogString "Obtaining distributed switch configuration..."
    $DistributedSwitches = Get-VDSwitch -VMHost $HostToConfig
    if ($DistributedSwitches -eq $null -or $DistributedSwitches -eq "")
    {
        DoLogging -LogType Err -LogString "$HostToConfig is not joined to a distributed switch!!!"
        DoLogging -LogType Err -LogString "This MUST be corrected before putting the host in production!!!"
        DoLogging -LogType Err -LogString "To prevent loss of connectivity, this script will not correct this automatically!!!"
    }
    else
    {
        foreach ($DistributedSwitch in $DistributedSwitches)
        {
            $Nics = Get-VMHostNetworkAdapter -VMHost $HostToConfig -DistributedSwitch $DistributedSwitch -Physical | sort name
            if ($Nics.Count -lt 2)
            {
                DoLogging -LogType Err -LogString "Distributed switch '$DistributedSwitch' does not have at least 2 physical NICs!!!"
                DoLogging -LogType Err -LogString "This MUST be corrected before putting the host in production!!!"
                DoLogging -LogType Err -LogString "To prevent loss of connectivity, this script will not correct this automatically!!!"
            }
            else
            {
                DoLogging -LogType Succ -LogString "Distributed switch '$DistributedSwitch' has at least 2 physical NICs."
            }
        }
    }
}

##################
#VAAI and ALUA Config Check
##################
if ($CompellentAttached -eq "y")
{
    DoLogging -LogType Info -LogString "Host is attached to Compellent, checking and configuring VAAI and ALUA settings..."
    DoLogging -LogType Info -LogString "Checking HardwareAcceleratedMove setting..."
    $VAAIConfig = Get-AdvancedSetting -Entity $HostToConfig -Name DataMover.HardwareAcceleratedMove
    if ($VAAIConfig.Value -ne 1)
    {
        DoLogging -LogType Warn -LogString "HardwareAcceleratedMove is incorrect..."
	    $VAAIConfig | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null
    }
    else { DoLogging -LogType Succ -LogString "HardwareAcceleratedMove setting is correct." }

    DoLogging -LogType Info -LogString "Checking HardwareAcceleratedInit setting..."
    $VAAIConfig = Get-AdvancedSetting -Entity $HostToConfig -Name DataMover.HardwareAcceleratedInit
    if ($VAAIConfig.Value -ne 1)
    {
        DoLogging -LogType Warn -LogString "HardwareAcceleratedInit is incorrect..."
	    $VAAIConfig | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null
    }
    else { DoLogging -LogType Succ -LogString "HardwareAcceleratedInit setting is correct." }

    DoLogging -LogType Info -LogString "Checking HardwareAcceleratedLocking setting..."
    $VAAIConfig = Get-AdvancedSetting -Entity $HostToConfig -Name VMFS3.HardwareAcceleratedLocking
    if ($VAAIConfig.Value -ne 1)
    {
        DoLogging -LogType Warn -LogString "HardwareAcceleratedLocking is incorrect..."
	    $VAAIConfig | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null
    }
    else { DoLogging -LogType Succ -LogString "HardwareAcceleratedLocking setting is correct." }

    DoLogging -LogType Info -LogString "Connecting to the the host's CLI..."
    $esxcli = Get-EsxCli -V2 -VMHost $HostToConfig

    DoLogging -LogType Info -LogString "Checking default path selection policy setting for SATP 'VMW_SATP_ALUA'..."
    if ($($esxcli.storage.nmp.satp.list.Invoke() | where {$_.Name -eq "VMW_SATP_ALUA"}).DefaultPSP -ne "VMW_PSP_RR")
    {
        DoLogging -LogType Warn -LogString "Default path selection policy is incorrect..."
        $esxcli.storage.nmp.satp.set.Invoke(@{defaultpsp="VMW_PSP_RR";satp="VMW_SATP_ALUA"}) | Out-Null
        DoLogging -LogType Succ -LogString "Default path selection policy updated."
        DoLogging -LogType Warn -LogString "!!!THIS CHANGE REQUIRES A HOST REBOOT!!!"
    }
    else { DoLogging -LogType Succ -LogString "Path Selection Policy setting is correct." }

    DoLogging -LogType Info -LogString "Checking Compellent volume Storage Array Type..."
    $CompellentVolumeCheck = $esxcli.storage.nmp.device.list.Invoke() | ? { $_.DeviceDisplayName -like "COMPELNT*" -and $_.StorageArrayType -ne "VMW_SATP_ALUA" }
    if ($CompellentVolumeCheck -ne $null)
    {
        foreach($Volume in $CompellentVolumeCheck)
        {
            DoLogging -LogType Warn -LogString "Setting Storage Array Type for volume $($Volume.Device)..."
            $esxcli.storage.nmp.device.set.Invoke(@{device=$($Volume.Device);psp="VMW_SATP_ALUA"})
            DoLogging -LogType Succ -LogString "Storage Array Type set."
        }
    }
    else { DoLogging -LogType Succ -LogString "All Compellent volumes are set to the correct Storage Array Type." }
}
