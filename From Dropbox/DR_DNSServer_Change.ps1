$VMs = Get-VM | where {$_.ExtensionData.Guest.HostName -like "*Blah*"} | Sort-Object Name

$GuestUsername = "Administrator"
$GuestPassword = "Blah"

foreach ($VM in $VMs)
{
	$VM | Get-VMGuestNetworkInterface -GuestUser $GuestUsername -GuestPassword $GuestPassword -Name "Local Area Connection" | Set-VMGuestNetworkInterface -GuestUser $GuestUsername -GuestPassword $GuestPassword -Dns "Blah"
	
	$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$spec.tools = New-Object VMWare.Vim.ToolsConfigInfo
	$spec.tools.syncTimeWithHost = $true
	
	$MyVM = Get-View -Id $VM.Id
	$MyVM.ReconfigVM_Task($spec)
}