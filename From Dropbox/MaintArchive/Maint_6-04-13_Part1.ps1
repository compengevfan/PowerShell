$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

Move-VM -VM  tricofcusql -destination aspesxi33.criflending.com
Move-VM -VM  mdwfcuapp03 -destination aspesxi33.criflending.com
Move-VM -VM  CACOASTCUAPP01 -destination aspesxi33.criflending.com
Move-VM -VM  METROBANKSQL -destination aspesxi33.criflending.com
Move-VM -VM  STMARYSDOC -destination aspesxi33.criflending.com
Move-VM -VM  TRUSTMARKSQLC -destination aspesxi33.criflending.com
Move-VM -VM  SEVEN17APP02 -destination aspesxi33.criflending.com
Move-VM -VM  MARINEFCUAPP01 -destination aspesxi33.criflending.com
Move-VM -VM  BMWAPP07 -destination aspesxi33.criflending.com
Move-VM -VM  ARSENALCUAPP02 -destination aspesxi33.criflending.com

Restart-VMGuest -VM mdwfcuapp03
Restart-VMGuest -VM CACOASTCUAPP01
Restart-VMGuest -VM STMARYSDOC
Restart-VMGuest -VM SEVEN17APP02
Restart-VMGuest -VM MARINEFCUAPP01
Restart-VMGuest -VM BMWAPP07
Restart-VMGuest -VM ARSENALCUAPP02
Restart-VMGuest -VM tricofcusql
Restart-VMGuest -VM METROBANKSQL
Restart-VMGuest -VM TRUSTMARKSQLC