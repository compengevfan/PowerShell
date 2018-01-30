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

##################
#Verify ESXi build number. If wrong, exit.
##################
DoLogging -LogType Info -LogString "Checking ESXi build number..."
$OSInfo = Get-View -ViewType HostSystem -Filter @{"Name"=$($HostToConfig).Name} -Property Name,Config.Product | foreach {$_.Name, $_.Config.Product}
if ($OSInfo.Build -eq 5572656)
{
    DoLogging -LogType Info -LogString "ESXi build number is correct..."
}
else
{
    DoLogging -LogType Err -LogString "ESXi build number is incorrect!!! Please install the proper version of ESXi and try again. Script Exiting!!!"
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
if ($NTPServers -contains "ntp-cisco.footballfanatics.wh" -and $NTPServers.Count -eq 1)
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
	Add-VmHostNtpServer -NtpServer "ntp-cisco.footballfanatics.wh" -VmHost $HostToConfig | Out-Null
	Start-VMHostService $ntp -Confirm:$false | Out-Null
    DoLogging -LogType Succ -LogString "NTP Server config fixed."
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
DoLogging -LogType Info -LogString "Getting host mapping information from data file..."
$DataFromFile = Import-Csv .\HostConfigurator-Data.csv

$ParentCluster = $HostToConfig.Parent.Name

$ProperInfo = $DataFromFile | ? { $_.Cluster -eq $ParentCluster }

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
$powerpolicy | Select -ExpandProperty Info | Select -ExpandProperty CurrentPolicy
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

