$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

Move-VM -VM NASSAUSQL -datastore LUN_91-FC_LCC_SQL1