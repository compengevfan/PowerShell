$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver CRIFVC.myappro.com -user aspchrisd -password L1thiumCmwys5%

Move-VM -VM  LC3DSQLVM06P -destination aspesxi20.myappro.com
