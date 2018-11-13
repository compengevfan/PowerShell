$Servers = Get-Content G:\Dupree\Servers.txt

foreach ($Server in $Servers)
{
	$ConnectCheck = Test-Connection -ComputerName $Server -Count 1 -ErrorAction "SilentlyContinue"
	if ($ConnectCheck -ne $NULL)
	{
		$SCOMCheck = Get-Service -DisplayName "*System Center*" -ComputerName $Server -ErrorAction "SilentlyContinue"
		if ($SCOMCheck -ne $NULL)
		{
			Write-host $Server
		}
	}
}


Get-DataCenter ORD | Get-VM | where {$_.PowerState -eq "PoweredOn" -and $_.Guest -like "*Windows*"} | select Name | Sort-Object Name | Out-File C:\Temp\Servers.txt

Get-Cluster JAX-Prod* | Get-VM | where {$_.PowerState -eq "PoweredOn" -and $_.Guest -like "*Windows*"} | select Name | Sort-Object Name | Out-File C:\Temp\Servers.txt

Get-Cluster DEVQC | Get-VM | where {$_.PowerState -eq "PoweredOn" -and $_.Guest -like "*Windows*" -and $_.Guest.HostName -like "*.ff.p10"} | select Name | Sort-Object Name | Out-File C:\Temp\Servers.txt

****Begin Script****

$Servers = Import-CSV G:\Dupree\HaveSCOM.txt

$Count = 1

$ValidServices = 'AdtAgent','HealthService','System Center Management APM'

while ($Count -le 5)
{
	foreach ($Server in $Servers)
	{
        if ($Server.Group -eq $Count)
        {
			$Name = $Server.ServerName
			write-host $Name -foregroundcolor "magenta"
		    $Services = Get-Service -DisplayName "*System Center*" -ComputerName $Name -ErrorAction "SilentlyContinue"
		    foreach ($Service in $Services)
		    {
			    $ServiceName = $Service.Name
				if ($ValidServices -contains $ServiceName)
				{
					write-host $ServiceName -foregroundcolor "green"
					sc.exe \\$Name stop $ServiceName
					sc.exe \\$Name config $ServiceName start= disabled
				}
		    }
        }
	}
	$Count++
	
	if ($Count -ne 6)
	{
		$Date = Get-Date
		write-host $Date
		write-host "Wait 10 Minutes..."
		Start-Sleep 600
	}
	else
	{
		$Date = Get-Date
		write-host $Date
		write-host "Done."
	}
}