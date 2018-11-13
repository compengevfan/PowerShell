[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True)]
   [string]$filePath
)

$computers = Get-Content $filepath
ForEach ($computer in $computers)
{
	Stop-Service -InputObject $(Get-Service -Computer $computer -Name NetLogon)
	
	if (test-path \\$($Computer)\c$\Windows\debug\netlogon.log.bak)
	{
		remove-item \\$($Computer)\c$\Windows\debug\netlogon.log.bak
	}
	
	rename-item \\$($Computer)\c$\Windows\debug\netlogon.log \\$($Computer)\c$\Windows\debug\netlogon.log.bak
	
	Start-Service -InputObject $(Get-Service -Computer $computer -Name NetLogon)
}