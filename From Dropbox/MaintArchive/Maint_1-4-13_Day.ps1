$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

$VMs = Get-VM | where {$_.vmhost.parent.name -eq "LCC_Test"}

foreach ($VM in $VMs)
{
	$CD = Get-CDDrive $VM
	if ($CD.HostDevice -ne $NULL)
	{
		Set-CDDrive -CD $CD -NoMedia -Confirm:$false
	}
}