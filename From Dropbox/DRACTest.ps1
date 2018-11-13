$HostNames = Get-Content .\DRACTest.txt

foreach ($HostName in $HostNames)
{
	$DRACName = "rac-" + $HostName
	if(!(Test-Connection $DRACName -quiet))
	{
		write-host ("Can't connect to " + $DRACName)
	}
}