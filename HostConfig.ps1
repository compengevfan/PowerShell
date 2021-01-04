$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

connect-viserver blah.blah.blah

$VMHosts = Get-VMHost

foreach ($VMHost in $VMHosts)
{
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
	#Domain and domain look up is "evorigin.com" && DNS is 192.168.1.101 and Gateway is 192.168.1.1
	###################################################################
	$Network = Get-VMHostNetwork -VMHost $VMHost
	
	if ($Network.DomainName -ne "evorigin.com")
	{
		Set-VMHostNetwork $Network -DomainName "evorigin.com"
	}
	
	if ($Network.SearchDomain -ne "evorigin.com")
	{
		Set-VMHostNetwork $Network -SearchDomain "evorigin.com"
	}
	
	if ($Network.VMKernelGateway -ne "192.168.1.1")
	{
		Set-VMHostNetwork $Network -VMKernelGateway "192.168.1.1"
	}
	
	if (($Network.DnsAddress -contains "192.168.1.101") -and (($Network.DnsAddress.Count -eq 1) -or ($Network.DnsAddress.Count -eq $NULL)))
	{
		write-host ("Checked, OK!")
	}
	else #If the DNS servers are not correct, fix them.
	{
		Set-VMHostNetwork $Network -DnsAddress "192.168.1.101"
	}
	
	###################################################################
	#NTP Servers
	###################################################################
	$NTPServers = Get-VMHostNtpServer $VMHost
	
	$ntp = Get-VmHostService -VMhost $VMHost | Where {$_.Key -eq 'ntpd'}

	#Check the NTP Servers on the host.
	if (($NTPServers -contains "fallen.evorigin.com") -and (($NTPServers.Count -eq 1) -or ($NTPServers.Count -eq $NULL)))
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
		Add-VmHostNtpServer -NtpServer "fallen.evorigin.com" -VmHost $VMHost
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

	$SysLog = Get-VMHostSysLogServer -VMHost $VMHost -ErrorAction SilentlyContinue
	
	if ($SysLog -eq $NULL -or $SysLog.Count -ne 1)
	{
		Set-VMHostSysLogServer -VMhost $VMHost -SysLogServer 192.168.1.200 -SysLogServerPort 514
		$TheCLI = Get-EsxCli -VMHost $VMHost
		$TheCLI.system.syslog.reload()
	}
}

Disconnect-VIServer -Confirm:$false