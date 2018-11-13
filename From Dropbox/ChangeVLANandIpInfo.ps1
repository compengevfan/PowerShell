$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

connect-viserver togetheragain.evorigin.com

$NewVLAN = "VLAN600"
$GuestUsername = "Administrator"
$GuestPassword = "Blah"
$NewNetmask = "Blah"
$NewGateway = "Blah"

##Import VM Name and new IP address from CSV file

$Data = Import-Csv "C:\Cloud\Dropbox\Scripts\PowerCLI\Work\ChangeVLANandIpInfo_Data.txt"

##Perform updates

foreach ($Server in $Data)
{
	##Change VLAN
	
	$CurrentServer = Get-VM $Server.Name
	$CurrentServer | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $NewVLAN -Confirm:$false
	
	##Update IP information
	
	$NewIP = $Data.Ip
	$CurrentServer | Get-VMGuestNetworkInterface -GuestUser $GuestUsername -GuestPassword $GuestPassword -Name "Local Area Connection" | Set-VMGuestNetworkInterface -GuestUser $GuestUsername -GuestPassword $GuestPassword -IPPolicy Static -Ip $NewIP -Netmask $NewNetmask -Gateway $NewGateway
}