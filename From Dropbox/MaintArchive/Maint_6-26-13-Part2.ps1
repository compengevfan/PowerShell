$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver CRIFVC.criflending.com -user cdupree -password L1thiumCmwys5%

Set-Cluster LC3 -DrsAutomationLevel Manual -Confirm:$false

Get-VMHost aspesxi20.criflending.com | Set-VMHost -State Connected

Move-VM -VM LC3RSQLVM06P -destination aspesxi20.criflending.com
Move-VM -VM LC3A52APP01P -destination aspesxi20.criflending.com
Move-VM -VM LC3UI09P -destination aspesxi20.criflending.com
Move-VM -VM LC3AO02P -destination aspesxi20.criflending.com
Move-VM -VM APPRORISK12 -destination aspesxi20.criflending.com
Move-VM -VM LC3AO03P -destination aspesxi20.criflending.com
Move-VM -VM StrategyOne1 -destination aspesxi20.criflending.com
Move-VM -VM LC3CR01P -destination aspesxi20.criflending.com
Move-VM -VM LC3Utility -destination aspesxi20.criflending.com
Move-VM -VM LC3v50UI12P -destination aspesxi20.criflending.com

Set-Cluster LC3 -DrsAutomationLevel FullyAutomated -Confirm:$false