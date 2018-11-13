$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

$VMHosts = Get-VMHost Blah

foreach ($VMHost in $VMHosts)
{
	write-host("Processing server: " + $VMHost)
	###################################################################
	#SSH running and set to "start and stop with host"
	###################################################################
	$ssh = Get-VmHostService -VMhost $VMHost | Where {$_.Key -eq "TSM-SSH"}
	
	if ($ssh.Running -ne "True")
	{
		Start-VMHostService $ssh -Confirm:$false
	}
	
	if ($ssh.Policy -ne "on")
	{
		Set-VMHostService -HostService $ssh -Policy "on"
	}
	
	###################################################################
	#Turn off Shell Warning
	###################################################################
	$ShellChecks = Get-VMHostAdvancedConfiguration -Name UserVars.SuppressShellWarning -VMHost $VMHost
	$ShellCheck = $ShellChecks."UserVars.SuppressShellWarning"
	
	if ($ShellCheck -ne 1)
	{
		Set-VMHostAdvancedConfiguration -Name UserVars.SuppressShellWarning -Value 1 -VMHost $VMHost
	}

	###################################################################
	#Domain and domain look up is "Blah" && DNS is (Blah) and Gateway is Blah
	###################################################################
	$Network = Get-VMHostNetwork -VMHost $VMHost
	
	if ($Network.DomainName -ne "Blah")
	{
		Set-VMHostNetwork $Network -DomainName "Blah"
	}
	
	if ($Network.SearchDomain -ne "Blah")
	{
		Set-VMHostNetwork $Network -SearchDomain "Blah"
	}
	
	if ($Network.VMKernelGateway -ne "Blah")
	{
		Set-VMHostNetwork $Network -VMKernelGateway "Blah"
	}
	
	if (($Network.DnsAddress -contains "Blah") -and ($Network.DnsAddress -contains "Blah") -and (($Network.DnsAddress.Count -eq 2) -or ($Network.DnsAddress.Count -eq $NULL)))
	{
		write-host ("Checked, OK!")
	}
	else #If the DNS servers are not correct, fix them.
	{
		Set-VMHostNetwork $Network -DnsAddress "Blah"
	}
	
	###################################################################
	#NTP Servers
	###################################################################
	$NTPServers = Get-VMHostNtpServer $VMHost
	
	$ntp = Get-VmHostService -VMhost $VMHost | Where {$_.Key -eq 'ntpd'}

	#Check the NTP Servers on the host.
	if ((($NTPServers -contains "Blah") -or ($NTPServers -contains "Blah")) -and ($NTPServers.Count -eq 2))
	{
		write-host ("Checked, OK!")
	}
	else #If the NTP servers are not correct, fix them.
	{
		if ($ntp.Running -eq "True")
		{
			Stop-VMHostService $ntp -Confirm:$false
		}
		foreach ($NTPServer in $NTPServers)
		{
			Remove-VMHostNtpServer -NtpServer $NTPServer -VMHost $VMHost -Confirm:$false
		}
		Add-VmHostNtpServer -NtpServer "Blah" -VmHost $VMHost
		Add-VmHostNtpServer -NtpServer "Blah" -VmHost $VMHost
		Start-VMHostService $ntp -Confirm:$false
	}
	
	#Check to see if the NTP service is set to start and stop with the host.
	if ($ntp.Policy -ne "on")
	{
		Set-VMHostService -HostService $ntp -Policy "on"
	}

	###################################################################
	#Check and Disable VAAI
	###################################################################
	$VAAIs = Get-VMHostAdvancedConfiguration -VMHost $VMHost -Name DataMover.HardwareAcceleratedMove
	
	if ($VAAIs."DataMover.HardwareAcceleratedMove" -ne 0)
	{
		Set-VMHostAdvancedConfiguration -VMHost $VMHost -Name DataMover.HardwareAcceleratedMove -Value 0
	}

	$VAAIs = Get-VMHostAdvancedConfiguration -VMHost $VMHost -Name DataMover.HardwareAcceleratedInit
	
	if ($VAAIs."DataMover.HardwareAcceleratedInit" -ne 0)
	{
		Set-VMHostAdvancedConfiguration -VMHost $VMHost -Name DataMover.HardwareAcceleratedInit -Value 0
	}

	$VAAIs = Get-VMHostAdvancedConfiguration -VMHost $VMHost -Name VMFS3.HardwareAcceleratedLocking
	
	if ($VAAIs."VMFS3.HardwareAcceleratedLocking" -ne 0)
	{
		Set-VMHostAdvancedConfiguration -VMHost $VMHost -Name VMFS3.HardwareAcceleratedLocking -Value 0
	}

	###################################################################
	#Set syslog to appropriate syslog server
	###################################################################

}
