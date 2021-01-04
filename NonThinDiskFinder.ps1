$OutputFile = "C:\Temp\VMsWithaNonThinDisk.txt"

if (Test-Path $OutputFile) { del $OutputFile }

$VMs = Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"} | sort-object Name

foreach ($VM in $VMs)
{
	$Disks = Get-HardDisk -VM $VM
	
	$NonThinDisk = $false
	
	foreach ($Disk in $Disks)
	{
		if ($Disk.StorageFormat -ne "Thin")
		{
			$NonThinDisk = $true
		}
	}
	
	if ($NonThinDisk -eq $true)
	{
		 $VM.Name | Out-File -append $OutputFile
	}
}