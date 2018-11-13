$VMHosts = Get-VMHost

$alarmMgr = Get-View AlarmManager 

$Action = Read-Host("What would you like to do? (Enter '1' to disable, enter '2' to enable)")

if (($Action -ne 1) -and ($Action -ne 2))
{
	write-host("Invalid Entry. Exiting.")
	exit
}

if ($Action -eq 1)
{
	ForEach ($VMHost in $VMHosts)
	{
		$alarmMgr.EnableAlarmActions($VMHost.Extensiondata.MoRef,$false)
	}
}

if ($Action -eq 2)
{
	ForEach ($VMHost in $VMHosts)
	{
		$alarmMgr.EnableAlarmActions($VMHost.Extensiondata.MoRef, $true)
	}
}