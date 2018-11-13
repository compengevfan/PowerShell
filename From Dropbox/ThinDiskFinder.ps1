$OutputFile = "C:\ScriptOutput\VMsWithaThinDisk.txt"

if (Test-Path $OutputFile) { del $OutputFile }

$VMs = Get-VM | sort-object Name

foreach ($VM in $VMs)
{
	$Disks = Get-HardDisk -VM $VM
	
	$ThinDisk = $false
	
	foreach ($Disk in $Disks)
	{
		if ($Disk.StorageFormat -eq "Thin")
		{
			$ThinDisk = $true
		}
	}
	
	if ($ThinDisk -eq $true)
	{
		 $VM.Name | Out-File -append $OutputFile
	}
}