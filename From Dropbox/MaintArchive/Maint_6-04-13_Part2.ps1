$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

Restart-VMGuest -VM  TRICOAPP01
Restart-VMGuest -VM  TRICOAPP02
Restart-VMGuest -VM  TRICOFCURISK
Restart-VMGuest -VM  METROBANKAPP01
Restart-VMGuest -VM  METROBANKAPP1
Restart-VMGuest -VM  TRUSTMARKAPP01
Restart-VMGuest -VM  TRUSTMARKAPP02
