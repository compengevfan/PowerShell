$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

$OutputFile = "C:\ScriptOutput\SQLServerInfo.csv"

if (Test-Path $OutputFile) { del $OutputFile }

$VMs = Get-VM | where {$_.Name -like "*SQL*"} | Sort-Object Name

"Name,CPU Count,Memory (MB)" | Out-File -Append $OutputFile

foreach ($VM in $VMs)
{
	$VM.Name  + "," +  $VM.NumCPU  + "," +  $VM.MemoryMB | Out-File -Append $OutputFile
}