$CheckDelay = 5 #Delay between VM shutdown checks

$VM = Get-VM Blah

#Shutdown the VM
Shutdown-VMGuest -VM $VM -Confirm:$false

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	
	$Check = (Get-VM -Name $VM | select PowerState)
	if ($Check.PowerState -eq "PoweredOn")
	{
		$NotOffYet = "true"
		Write-Host ""
		Write-Host "VM shut down not complete..."
	}
}

#Clone the VM

New-VM -Name Blah_Clone -VM $VM -Datastore Blah -vmhost Blah -DiskStorageFormat thin

#Start the clone

$VMClone = Get-VM Blah_Clone

Start-VM -VM $VMClone

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	$Check = (Get-VM -Name $VMClone | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
	if ($Check.ToolsStatus -eq "toolsNotRunning")
		{
			$NotOnYet = "true"
			Write-Host ""
			Write-Host "VM start up not complete..."
		}
}

Write-Host ""
Write-Host("DR DC clone is ready.")
