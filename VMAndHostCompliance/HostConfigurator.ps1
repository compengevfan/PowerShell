[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter,
    [Parameter()] [string] $HostToCheck
)

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

DoLogging -LogType Info -LogString "Getting Domain, domain look up, DNS Servers and Gateway information..."
$Network = Get-VMHostNetwork -VMHost $VMHost

DoLogging -LogType Info -LogString "Checking domain name..."
if ($Network.DomainName -ne "evorigin.com")
{
	Set-VMHostNetwork $Network -DomainName "evorigin.com"
}
else
{
    DoLogging -LogType Succ -LogString "."
}

DoLogging -LogType Info -LogString "Checking search domain..."
if ($Network.SearchDomain -ne "evorigin.com")
{
	Set-VMHostNetwork $Network -SearchDomain "evorigin.com"
}
else
{
    DoLogging -LogType Succ -LogString "."
}

DoLogging -LogType Info -LogString "Checking Gateway"
if ($Network.VMKernelGateway -ne "192.168.1.1")
{
	Set-VMHostNetwork $Network -VMKernelGateway "192.168.1.1"
}
else
{
    DoLogging -LogType Succ -LogString "."
}

DoLogging -LogType Info -LogString "Checking DNS Servers"
if (($Network.DnsAddress -contains "192.168.1.101") -and (($Network.DnsAddress.Count -eq 1) -or ($Network.DnsAddress.Count -eq $NULL)))
{
	write-host ("Checked, OK!")
}
else #If the DNS servers are not correct, fix them.
{
	Set-VMHostNetwork $Network -DnsAddress "192.168.1.101"
}

