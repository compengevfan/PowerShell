$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

# Email parameters for emailing logfile results
# emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "CRIFVC@criflending.com"
$emailTo = "vmwaresupport@criflending.com"
$emailSubject = "Host CPU/Memory Allocation"
$emailServer = "aspexchange.myappro.com"

$FileLocation = "C:\Scripts\CPUAllocation.txt"

if (Test-Path $FileLocation) { del $FileLocation }

write-host("Retrieving list of Clusters...")
$Clusters = get-cluster | Sort-Object Name

write-host("Retrieving list of Hosts...")
$VMHosts = get-vmhost | Sort-Object Name

write-host("Retrieving list of VMs...")
$VMs = get-vm | Sort-Object Name

[int] $ClusterCPUsAvail = 0
[int] $ClusterCPUsAlloc = 0

[int] $HostCPUsAvail = 0
[int] $HostCPUsAlloc = 0

[int] $ClusterMemAvail = 0
[int] $ClusterMemAlloc = 0

[int] $HostMemAvail = 0
[int] $HostMemAlloc = 0

$TempString = ""

foreach ($Cluster in $Clusters)
{
	write-host ("Processing Cluster " + $Cluster + ".")
	
	$TempString = "Current Cluster is " + $Cluster + "."
	$TempString | out-file $FileLocation -append
	
	$CurrClusterHosts = $VMHosts | where {$_.Parent.Name -eq $Cluster}
	
	foreach ($CurrClusterHost in $CurrClusterHosts)
	{
		$CurrHostVMs = $VMs | where {$_.VMHost.Name -eq $CurrClusterHost}
		
		foreach ($CurrHostVM in $CurrHostVMs)
		{
			$HostCPUsAlloc += $CurrHostVM.NumCPU
			$HostMemAlloc += $CurrHostVM.MemoryMB
		}
		
		$HostCPUsAvail = $CurrClusterHost.NumCPU
		$HostMemAvail = $CurrClusterHost.MemoryTotalMB
		
		$TempString = ""
		$TempString | out-file $FileLocation -append
		$TempString = "Current host is " + $CurrClusterHost + "."
		$TempString | out-file $FileLocation -append
		$TempString = "Allocated CPUs: " + $HostCPUsAlloc + "."
		$TempString | out-file $FileLocation -append
		$TempString = "Available CPUs: " + $HostCPUsAvail + "."
		$TempString | out-file $FileLocation -append
		
		$Ratio = $HostCPUsAlloc / $HostCPUsAvail
		
		$TempString = "Ratio is " + $Ratio + "."
		$TempString | out-file $FileLocation -append
		
		$TempString = ""
		$TempString | out-file $FileLocation -append
		$TempString = "Allocated Memory: " + $HostMemAlloc + "."
		$TempString | out-file $FileLocation -append
		$TempString = "Available Memory: " + $HostMemAvail + "."
		$TempString | out-file $FileLocation -append
		
		$Ratio = $HostMemAlloc / $HostMemAvail
		
		$TempString = "Ratio is " + $Ratio + "."
		$TempString | out-file $FileLocation -append
		
		$ClusterCPUsAlloc += $HostCPUsAlloc
		$ClusterMemAlloc += $HostMemAlloc
		
		$ClusterCPUsAvail += $HostCPUsAvail
		$ClusterMemAvail += $HostMemAvail
		
		$HostCPUsAlloc = 0
		$HostMemAlloc = 0
	}
	
	$TempString = ""
	$TempString | out-file $FileLocation -append
	$TempString = "Cluster Allocated CPUs: " + $ClusterCPUsAlloc + "."
	$TempString | out-file $FileLocation -append
	$TempString = "Cluster Available CPUs: " + $ClusterCPUsAvail + "."
	$TempString | out-file $FileLocation -append
	
	$Ratio = $ClusterCPUsAlloc / $ClusterCPUsAvail
	
	$TempString = "Ratio is " + $Ratio + "."
	$TempString | out-file $FileLocation -append
	
	$TempString = ""
	$TempString | out-file $FileLocation -append
	$TempString = "Cluster Allocated Memory: " + $ClusterMemAlloc + "."
	$TempString | out-file $FileLocation -append
	$TempString = "Cluster Available Memory: " + $ClusterMemAvail + "."
	$TempString | out-file $FileLocation -append
	
	$Ratio = $ClusterMemAlloc / $ClusterMemAvail
	
	$TempString = "Ratio is " + $Ratio + "."
	$TempString | out-file $FileLocation -append
	
	$TempString = ""
	$TempString | out-file $FileLocation -append
	$TempString = "=========================================================="
	$TempString | out-file $FileLocation -append
	$TempString = ""
	$TempString | out-file $FileLocation -append
	
	$ClusterCPUsAlloc = 0
	$ClusterCPUsAvail = 0
	
	$ClusterMemAlloc = 0
	$ClusterMemAvail = 0
}

Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject $emailSubject -body (Get-Content $FileLocation | Out-String)