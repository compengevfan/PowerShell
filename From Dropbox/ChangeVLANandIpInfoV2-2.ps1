$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver CRIFVC.myappro.com -user aspchrisd -password L1thiumCmwys5%

$NewVLAN = "VLAN628"
$GuestUsername = "Administrator"
$GuestPassword = "Blah"
$NewNetmask = "255.255.255.128"
$NewGateway = "10.110.47.129"

##Import VM Name and new IP address from CSV file

$Data = Import-Csv "C:\Cloud\Dropbox\Scripts\PowerCLI\Work\ChangeVLANandIpInfo_Data2.txt"

##Perform updates

foreach ($Server in $Data)
{
	##Change VLAN
	
	$CurrentServer = Get-VM $Server.Name
	$CurrentServer | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $NewVLAN -Confirm:$false
		
	##Change IP
	$NewIP = $Server.IP
	$CurrentServer | Get-VMGuestNetworkInterface -GuestUser $GuestUsername -GuestPassword $GuestPassword -Name "Local Area Connection 3" | Set-VMGuestNetworkInterface -GuestUser $GuestUsername -GuestPassword $GuestPassword -IPPolicy Static -Ip $NewIP -Netmask $NewNetmask -Gateway $NewGateway
	
	##Reboot VM
	Restart-VMGuest -VM $VM -Confirm:$false
}