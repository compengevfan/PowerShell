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
$FromAddress = "CRIFVC@criflending.com"
$Subject = "CRIFVC VM Config Problems Detected!!!"
$SMTPServer = "aspexchange.myappro.com"

connect-viserver crifvc.criflending.com

$VMs = Get-VM

$EmailBody = ("Please correct the following VMs.`n`n")

foreach ($VM in $VMs)
{
	#Check to see if the CD-ROM is set to "Host Device"
	$CD = Get-CDDrive $VM
	if ($CD.HostDevice -ne $NULL)
	{
		$CDProblems = ($VM + "`n")
	}
	
	#Check to see if the VM has an active snapshot3
	$SnapShot = Get-Snapshot -VM $VM
	if ($Snapshot -ne $NULL)
	{
		$SnapProblems = ($VM + "`n")
	}
}

$ProblemDetected = 0

if ($CDProblems -ne $NULL)
{
	$ProblemDetected = 1
	$EmailBody = ($EmailBody + "VMs with CDROM set to 'Host Device':`n" + $CDProblems)
}

if (SnapProblems -ne $NULL)
{
	$ProblemDetected = 1
	$EmailBody = ($EmailBody + "VMs with an active snapshot:`n" + $SnapProblems)
}

if ($problemDetected -eq 1)
{
	Send-MailMessage -To $ToAddress -Subject $Subject -Body $EmailBody -SmtpServer $SMTPServer -From $FromAddress -Priority High
}