$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

Move-VM -VM asparchive1.MYAPPRO.COM -datastore 480_LUN_102-FC_LCC_ARCHIVE
Move-VM -VM BMWARCHIVE -datastore 480_LUN_100-FC_BMWARCHIVE
Move-VM -VM CAPONEARCHIVE.MYAPPRO.COM -datastore 480_LUN_102-FC_LCC_ARCHIVE
Move-VM -VM cuacarchive.MYAPPRO.COM -datastore 480_LUN_102-FC_LCC_ARCHIVE
