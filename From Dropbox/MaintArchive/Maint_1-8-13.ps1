$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

$Limits = Get-VM | where {$_.vmhost.parent.name -eq "PROD_BU"} | Get-VMResourceConfiguration | where {$_.memlimitmb -ne -1}

foreach ($Limit in $Limits)
{
	Set-VMResourceConfiguration $Limit -MemLimitMB $NULL
}