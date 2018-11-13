$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

$VMs = Get-VM | where {$_.vmhost.parent.name -ne "LCC_Test"}

foreach ($VM in $VMs)
{
	$CD = Get-CDDrive $VM
	if ($CD.HostDevice -ne $NULL)
	{
		Set-CDDrive -CD $CD -NoMedia -Confirm:$false
	}
}

$Limits = Get-VM | where {$_.vmhost.parent.name -eq "PROD2"} | Get-VMResourceConfiguration | where {$_.memlimitmb -ne -1}

foreach ($Limit in $Limits)
{
	Set-VMResourceConfiguration $Limit -MemLimitMB $NULL
}

Move-VM -VM CNTRLBANKHSQL -datastore LUN_99-FC_LCC_SQL9