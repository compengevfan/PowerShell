$Data = Import-Csv "C:\Cloud\Dropbox\Scripts\PowerCLI\Work\FixVDSIssues_Data.txt"
$VMs = Get-VM

Import-Module C:\Cloud\Dropbox\Scripts\PowerCLI\Work\CheckForDVSIssueWithNoVDSSnapin.ps1

foreach ($Server in $Data)
{
	$VMs | where-object {$_.Name -eq $Server.Name} | Test-VDSVMIssue -Fix
}