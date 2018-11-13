$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver togetheragain.evorigin.com

$DNSServer = "fallen"
$DNSForwardZone = "evorigin.com"
$DNSReverseZone = "1.168.192.in-addr.arpa"

$Data = Import-Csv "C:\Cloud\Dropbox\Scripts\PowerCLI\Personal\ChangeVLANandIpInfo_Data.txt"

foreach ($Server in $Data)
{

	$CurrentServer = Get-VM $Server.Name
	
	##Update DNS
	
	$ServerName = $CurrentServer.Name
	$NewIP = $Server.Ip
	
	$OldIP = $CurrentServer.guest.ipaddress
	$Octet4 = ([ipaddress] "$OldIP").GetAddressBytes()[3]
	
	##Delete Reverse Record
	$FQDN = $ServerName + "." + $DNSForwardZone
	$cmdDeletePTR = "dnscmd $DNSServer /RecordDelete $DNSReverseZone $Octet4 PTR $FQDN /f"
	Invoke-Expression $cmdDeletePTR
	
	##Delete Forward Record
	$cmdDeleteA = "dnscmd $DNSServer /RecordDelete $DNSForwardZone $ServerName A /f"
	Invoke-Expression $cmdDeleteA
	
	##Add Forward Record and create reverse record
	$cmdAddA = "dnscmd $DNSServer /RecordAdd $DNSForwardZone $ServerName /CreatePTR A $NewIP"
	Invoke-Expression $cmdAddA
}