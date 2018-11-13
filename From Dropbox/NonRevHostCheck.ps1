$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

###################################################################
#Email Variables
###################################################################

$ToAddress = "vmwaresupport@criflending.com"
$FromAddress = "CORPVC@criflending.com"
$Subject = "CORPVC Host Config Problems Detected!!!"
$SMTPServer = "relay.us.crifnet.com"

connect-viserver corpvc.us.crifnet.com

$VMHosts = Get-VMHost

foreach ($VMHost in $VMHosts)
{
	$ProblemDetected = 0
	$EmailBody = ("Server: " + $VMHost + "`n`n")
	$EmailBody = $EmailBody + ("Problems found:" + "`n")
	
	###################################################################
	#SSH running and set to "start and stop with host"
	###################################################################
	$ssh = Get-VmHostService -VMhost $VMHost | Where {$_.Key -eq "TSM-SSH"}
	
	if ($ssh.Running -ne "True")
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "SSH Service is not running.`n"
	}
	
	if ($ssh.Policy -ne "on")
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "SSH Service is not set to start and stop with host.`n"
	}
	
	###################################################################
	#Turn off Shell Warning
	###################################################################
	$ShellChecks = Get-VMHostAdvancedConfiguration -Name UserVars.SuppressShellWarning -VMHost $VMHost
	$ShellCheck = $ShellChecks."UserVars.SuppressShellWarning"
	
	if ($ShellCheck -ne 1)
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "Shell/SSH warning is not suppressed.`n"
	}

	###################################################################
	#Domain and domain look up is "us.crifnet.com" && DNS is (10.110.16.101, 10.110.16.102) and Gateway is 10.110.8.1
	###################################################################
	$Network = Get-VMHostNetwork -VMHost $VMHost
	
	if ($Network.DomainName -ne "us.crifnet.com")
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "Server domain is incorrect.`n"
	}
	
	if ($Network.SearchDomain -ne "us.crifnet.com")
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "Domain look up list is incorrect.`n"
	}
	
	if ($Network.VMKernelGateway -ne "10.110.8.1")
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "Server gateway address is incorrect.`n"
	}
	
	if (($Network.DnsAddress -contains "10.110.16.101") -and ($Network.DnsAddress -contains "10.110.16.102") -and (($Network.DnsAddress.Count -eq 2) -or ($Network.DnsAddress.Count -eq $NULL)))
	{
		write-host ("Checked, OK!")
	}
	else #If the DNS servers are not correct, fix them.
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "DNS server(s) are incorrect.`n"
	}
	
	###################################################################
	#NTP Servers
	###################################################################
	$NTPServers = Get-VMHostNtpServer $VMHost
	
	$ntp = Get-VmHostService -VMhost $VMHost | Where {$_.Key -eq 'ntpd'}

	#Check the NTP Servers on the host.
	if ((($NTPServers -contains "tick.myappro.com") -or ($NTPServers -contains "tock.myappro.com")) -and ($NTPServers.Count -eq 2))
	{
		write-host ("Checked, OK!")
	}
	else #If the NTP servers are not correct, fix them.
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "NTP servers are incorrect.`n"
	}
	
	#Check to see if the NTP service is set to start and stop with the host.
	if ($ntp.Policy -ne "on")
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "NTP service is not set to start and stop with host.`n"
	}

	###################################################################
	#Check and Disable VAAI
	###################################################################
	$VAAIs = Get-VMHostAdvancedConfiguration -VMHost $VMHost -Name DataMover.HardwareAcceleratedMove
	
	if ($VAAIs."DataMover.HardwareAcceleratedMove" -ne 0)
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "DataMover.HardwareAcceleratedMove option is enabled. (Change requires reboot.)`n"
	}

	$VAAIs = Get-VMHostAdvancedConfiguration -VMHost $VMHost -Name DataMover.HardwareAcceleratedInit
	
	if ($VAAIs."DataMover.HardwareAcceleratedInit" -ne 0)
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "DataMover.HardwareAcceleratedInit option is enabled. (Change requires reboot.)`n"
	}

	$VAAIs = Get-VMHostAdvancedConfiguration -VMHost $VMHost -Name VMFS3.HardwareAcceleratedLocking
	
	if ($VAAIs."VMFS3.HardwareAcceleratedLocking" -ne 0)
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "VMFS3.HardwareAcceleratedLocking option is enabled. (Change requires reboot.)`n"
	}

	###################################################################
	#Check vSwitch Portgroup names
	###################################################################
	
	$PortGroupCheckResult = 0
	
	$PortGroups = Get-VirtualPortGroup $VMHost | where {$_.key -notlike "dv*"}
	
	$PortGroupCheck = $PortGroups | where {$_.Name -eq "vMotion"}
	if ($PortGroupCheck -eq $NULL)
	{
		$PortGroupCheckResult = 1
	}
	$PortGroupCheck = $PortGroups | where {$_.Name -eq "Management Network"}
	if ($PortGroupCheck -eq $NULL)
	{
		$PortGroupCheckResult = 1
	}

	if ($PortGroupCheckResult -eq 1)
	{
		$ProblemDetected = 1
		$EmailBody = $EmailBody + "vSwitch portgroup names are incorrect.`n"
	}

	###################################################################
	#Set syslog to appropriate syslog server
	###################################################################
	
	###################################################################
	#Check to see if an email needs to go out. If so, send it
	###################################################################
	$EmailBody = $EmailBody + "`n`nPlease correct these problems as soon as possible!"
	
	if ($ProblemDetected -eq 1)
	{
		Send-MailMessage -To $ToAddress -Subject $Subject -Body $EmailBody -SmtpServer $SMTPServer -From $FromAddress -Priority High
	}

	Clear-Variable EmailBody
}

Disconnect-VIServer -Confirm:$false