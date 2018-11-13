$OutputFile = "C:\ScriptOutput\LUNsToCheck.txt"

if (Test-Path $OutputFile) { del $OutputFile }

$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

$Data = Import-Csv "C:\Cloud\Dropbox\Scripts\PowerCLI\Work\VerifyReplicationData.txt"

$LUNsToCheck = @()

foreach ($Server in $Data)
{
	$LUNs = Get-VM $Server.Name | Get-Datastore | select Name | where {$_.Name -notlike "*vswp*"}
	
	foreach ($LUN in $LUNs)
	{
		if ($LUNsToCheck -notcontains $LUN.Name)
		{
			$LUNsToCheck += $LUN.Name
		}
	}
}

$LUNsToCheck | Out-File -append $OutputFile