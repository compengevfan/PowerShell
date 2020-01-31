$Hosts = Get-VMHost

#Set Syslog Server
$Hosts | Get-AdvancedSetting -Name Syslog.Global.Loghost | Set-AdvancedSetting -Value udp://vlog-prod.csxt.csx.com:514 -Confirm:$false

#Restart Syslog Service
foreach ($CurrentHost in $Hosts)
{
	$Service = Get-VMHostService -VMHost $CurrentHost | where {$_.Key -eq 'vmsyslogd'}
	Restart-VMHostService -HostService $Service -Confirm:$false
}