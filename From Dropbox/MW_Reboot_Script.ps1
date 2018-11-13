$ClusterName = Read-Host "Please enter the name of the cluster containing the VM's to be restarted"

Write-Host ""
Write-Host "Retrieving VM list..."

$ClusterVMs = Get-VM | where {$_.vmhost.parent.name -eq $ClusterName}

###################################################################
#Wait and Verify                                                  #
###################################################################

$CheckDelay = 5 #Delay between VM shutdown checks
$SettleDelay = 10 #Delay between group actions
$StartDelay = 30 #Delay between shut down and start up

Write-Host ""
$Verify = Read-Host "Are you sure you want to proceed with restart? (type 'yes' to continue)"

if ($Verify -ne "yes")
{
	exit
}

###################################################################
#Shut down VM's by Group                                          #
###################################################################

$i = 59

while ($i -gt 9)
{
	$WorkGroup = @()
	foreach ($ClusterVM in $ClusterVMs)
	{
		$CustomFields = $ClusterVM.CustomFields | select Key, Value
		$CustomField = $CustomFields | where {$_.Key -eq "Reboot Order"}
		if ($CustomField.Value -eq $i)
		{
			$WorkGroup += $ClusterVM.Name
		}
	}
	
	if ($WorkGroup.count -gt 0)
	{
		write-host("Shutting down VM's in group " + $i + ".")
		
		ForEach ($VM in $WorkGroup) {Shutdown-VMGuest -VM $VM -Confirm:$false}
		
		$NotOffYet = "true"

		while ($NotOffYet -eq "true") 
		{
			start-sleep -s $CheckDelay
			$NotOffYet = "false"
			ForEach ($VM in $WorkGroup)
			{
				$Check = (Get-VM -Name $VM | select PowerState)
				if ($Check.PowerState -eq "PoweredOn")
					{
						$NotOffYet = "true"
					}
			}
			Write-Host ""
			Write-Host "VM shut down not complete..."
		}
		Write-Host ""
		Write-Host("VM's in Group " + $i + " have been shut down.")
		
		Write-Host ""
		Write-Host "Waiting for everything to settle down..."
		Write-Host ""
		start-sleep -s $SettleDelay
	}
	
	clear-variable WorkGroup
	$i -= 1
}

###################################################################
#End Shutdown VM's by Group                                       #
###################################################################

Write-Host ""
Write-Host "Preparing to start VM's..."
Write-Host ""
start-sleep -s $StartDelay

###################################################################
#Power On VM's by group                                           #
###################################################################

$i = 10

while ($i -lt 60)
{
	$WorkGroup = @()
	foreach ($ClusterVM in $ClusterVMs)
	{
		$CustomFields = $ClusterVM.CustomFields | select Key, Value
		$CustomField = $CustomFields | where {$_.Key -eq "Reboot Order"}
		if ($CustomField.Value -eq $i)
		{
			$WorkGroup += $ClusterVM.Name
		}
	}
	
	if ($WorkGroup.count -gt 0)
	{
		Write-Host("Starting up VM's in Group " + $i + ".")
		ForEach ($VM in $WorkGroup) {Start-VM -VM $VM}

		$NotOnYet = "true"

		while ($NotOnYet -eq "true") 
		{
			start-sleep -s $CheckDelay
			$NotOnYet = "false"
			ForEach ($VM in $WorkGroup)
			{
				$Check = (Get-VM -Name $VM | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
				if ($Check.ToolsStatus -eq "toolsNotRunning")
					{
						$NotOnYet = "true"
					}
			}
			Write-Host ""
			Write-Host "VM start up not complete..."
		}
		Write-Host ""
		Write-Host("VM's in Group " + $i + " have been started up.")
		
		Write-Host ""
		Write-Host "Waiting for everything to settle down..."
		Write-Host ""
		start-sleep -s $SettleDelay
	}
	
	clear-variable WorkGroup
	$i += 1
}