$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

$Limits = Get-VM | where {$_.vmhost.parent.name -eq "INFRA"} | Get-VMResourceConfiguration | where {$_.memlimitmb -ne -1}

foreach ($Limit in $Limits)
{
	Set-VMResourceConfiguration $Limit -MemLimitMB $NULL
}

Move-VM -VM ASPMIMSP -datastore LUN_12-FC_INFRA5
Move-VM -VM ASPMIMST -datastore LUN_9-FC_INFRA2
Move-VM -VM BMWLOADSQLT2 -datastore 480_LUN_1105-FC_LCC_SQLT2C
Move-VM -VM BMWNEW -datastore 480_LUN_1105-FC_LCC_SQLT2C
Move-VM -VM CNTRLBANKHAPP1 -datastore LUN_46-FC_LCC_APP4
Move-VM -VM CNTRLBANKHAPP2 -datastore LUN_46-FC_LCC_APP4
Move-VM -VM LC3DSQLVM03T -datastore 480_LUN_444-FC_LC3_TEST8
Move-VM -VM LC3RSQLVM03T -datastore 480_LUN_444-FC_LC3_TEST8
Move-VM -VM LC3SSQLVM03T -datastore 480_LUN_444-FC_LC3_TEST8
Move-VM -VM XENAPPVMTEST -datastore LUN_11-FC_INFRA4