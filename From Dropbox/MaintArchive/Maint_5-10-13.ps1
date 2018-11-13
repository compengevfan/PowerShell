$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

Move-VM -VM COMAMERICAAPP1T -datastore 480_LUN_1118-FC_LCC_SQLT3A
Move-VM -VM DESERTAPP02T -datastore 480_LUN_1118-FC_LCC_SQLT3A
Move-VM -VM DESERTSQLT -datastore 480_LUN_1118-FC_LCC_SQLT3A
Move-VM -VM FIRSTSBOWSQLT -datastore 480_LUN_1118-FC_LCC_SQLT3A
Move-VM -VM FIVEPOINTAPP01T -datastore 480_LUN_1118-FC_LCC_SQLT3A
Move-VM -VM FNBPASQLT2 -datastore 480_LUN_1118-FC_LCC_SQLT3A
Move-VM -VM SNAPONSQLT -datastore 480_LUN_1118-FC_LCC_SQLT3A
Move-VM -VM ZIONSQL01T -datastore 480_LUN_1118-FC_LCC_SQLT3A
Move-VM -VM AMFIRSTSQLT -datastore 480_LUN_1119-FC_LCC_SQLT3B
Move-VM -VM HIBERNIASQLT -datastore 480_LUN_1119-FC_LCC_SQLT3B
Move-VM -VM IDAHOCCUSQLT -datastore 480_LUN_1119-FC_LCC_SQLT3B
Move-VM -VM LACAPAPP01T -datastore 480_LUN_1119-FC_LCC_SQLT3B
Move-VM -VM LACAPSQLT -datastore 480_LUN_1119-FC_LCC_SQLT3B
Move-VM -VM NHSBAPP01T -datastore 480_LUN_1119-FC_LCC_SQLT3B
Move-VM -VM SANCUAPP01T -datastore 480_LUN_1119-FC_LCC_SQLT3B
