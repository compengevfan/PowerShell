$Servers = Get-Content .\RemoteRegistry.txt

foreach ($Server in $Servers)
{
	$Service = Get-Service "Remote Registry" -ComputerName $Server
	$Service.Start()
}