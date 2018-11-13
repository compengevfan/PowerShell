$servers = Get-Content C:\ScriptOutput\AimbridgeVMs.txt

$creds = Get-Credential

foreach ($server in $servers)
{
	$Disk = Get-WMIObject Win32_DiskDrive -computer $server -credential $creds | where {$_.DeviceID -eq "\\.\PHYSICALDRIVE0"}
	if ($Disk.Partitions -gt 1)
	{
		$server | Out-File -Append C:\ScriptOutput\AimbridgeBadP2V.txt
	}
}
