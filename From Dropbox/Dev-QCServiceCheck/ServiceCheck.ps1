$Files = gci .\*.CSV

foreach ($File in $Files)
{
	$ServerName = $File.BaseName
	$Services = Import-CSV $File
	
	foreach ($Service in $Services)
	{
		$ServiceToCheck = $Service.ServiceName
		switch ($Service.ServiceType)
		{
			"IIS"
			{
				$AppPool = Get-WmiObject -Namespace 'root\webadministration' -Class ApplicationPool -ComputerName $ServerName -Authentication 6 -Filter "Name='$ServiceToCheck'"
				if ($AppPool -eq $NULL)
				{
					write-host ("$ServerName" + "." + $ServiceToCheck + " does not exist!!! (IIS)")  -foregroundcolor "magenta"
				}
				else
				{
					$AppPoolState = $AppPool.GetState()
					
					if ($AppPoolState.ReturnValue -eq 1)
					{
						#write-host ("$ServerName" + "." + $AppPool.Name + " is OK.") -foregroundcolor "white"
					}
					
					if ($AppPoolState.ReturnValue -eq 3)
					{
						write-host ("$ServerName" + "." + $AppPool.Name + " needs to be started!!! (IIS)") -foregroundcolor "yellow"
						$AppPool | Invoke-WmiMethod -Name Start
					}
				}
			}
			"Win"
			{
				$WinService = Get-Service -Name $Service.ServiceName -ComputerName $ServerName -ErrorAction SilentlyContinue
				if ($WinService -eq $NULL)
				{
					write-host ("$ServerName" + "." + $ServiceToCheck + " does not exist!!! (Win)")  -foregroundcolor "magenta"
				}
				else
				{
					if ($WinService.Status -eq "Stopped")
					{
						$ServiceCheck = Get-WmiObject win32_service -ComputerName $ServerName -Filter "Name='$ServiceToCheck'"
						if ($ServiceCheck.StartMode -eq "Disabled")
						{
							write-host ("$ServerName" + "." + $WinService.Name + " is DISABLED!!!") -foregroundcolor "red"
						}
						else
						{
							write-host ("$ServerName" + "." + $WinService.Name + " needs to be started!!! (Win)") -foregroundcolor "yellow"
							$WinService.Start()
						}
					}
					else
					{
						#write-host ("$ServerName" + "." + $WinService.Name + " is OK.") -foregroundcolor "white" 
					}
				}
			}
		}
	}
}