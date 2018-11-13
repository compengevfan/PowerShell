$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

Move-VM -VM FNBPASQL -datastore LUN_101-FC_LCC_SQL11
Move-VM -VM SACUSQLCLS -datastore LUN_99-FC_LCC_SQL9
Move-VM -VM STMARYSSQL -datastore LUN_96-FC_LCC_SQL6
