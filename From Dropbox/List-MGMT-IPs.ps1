$VMHostsNR = get-content .\No-Reply.txt

foreach ($VMHostNR in $VMHostsNR)
{
	write-host ("$VMHostNR")
	$IPs = Get-VMHostNetworkAdapter $VMHostNR | where {$_.ManagementTrafficEnabled -eq "True"} | select IP
	write-host ($IPs.IP)
	write-host ("")
}
