$DRACNames = get-content .\DRACNames.txt

$ips = @()

foreach ($DRACName in $DRACNames)
{
	$ips += [System.Net.Dns]::GetHostAddresses("$DRACName")
}