$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver togetheragain.evorigin.com

Move-VM -VM Anywhere -datastore StarWind
Move-VM -VM Eternal -datastore StarWind
Move-VM -VM Lithium -datastore StarWind
Move-VM -VM Solitude -datastore StarWind
Move-VM -VM TakingOverMe -datastore StarWind
Move-VM -VM Win2012 -datastore StarWind
Move-VM -VM Windows8 -datastore StarWind
