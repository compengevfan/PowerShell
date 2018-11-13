$Servers = Get-Content .\AddPhysicalDiskSizes.txt

foreach ($Server in $Servers)
{
	$Disks = get-WmiObject win32_diskdrive -Computername $Server
	$TotalSize = 0
	foreach ($Disk in $Disks)
	{
		$TotalSize += $Disk.Size
	}
	
	$SizeInGB = $TotalSize / 1GB
	write-host ("$Server " + "$SizeInGB")
}