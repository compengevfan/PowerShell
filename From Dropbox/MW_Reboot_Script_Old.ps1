$CheckDelay = 5 #Delay between VM shutdown checks
$SettleDelay = 10 #Delay between group actions
$StartDelay = 30 #Delay between shut down and start up

###################################################################
#Obtain VM Groups                                                 #
###################################################################

#Group 5.3
$VMLongArray53 = @()
$VMShortArray53 = @()

Write-Host "Retrieving list of servers in Group 5.3"
$VMAnnotation53 = Get-VM | Get-Annotation -CustomAttribute "Reboot Order" | Where {$_.value -eq "5.3"}

Write-Host "Organizing list, step 1"
ForEach ($VM in $VMAnnotation53) {$VMLongArray53 += $VM.AnnotatedEntity}

Write-Host "Organizing list, step 2"
ForEach ($VM in $VMLongArra53) {$VMShortArray53 += $VM | select Name}

#Group 5.2
$VMLongArray52 = @()
$VMShortArray52 = @()

Write-Host "Retrieving list of servers in Group 5.2"
$VMAnnotation52 = Get-VM | Get-Annotation -CustomAttribute "Reboot Order" | Where {$_.value -eq "5.2"}

Write-Host "Organizing list, step 1"
ForEach ($VM in $VMAnnotation52) {$VMLongArray52 += $VM.AnnotatedEntity}

Write-Host "Organizing list, step 2"
ForEach ($VM in $VMLongArray52) {$VMShortArray52 += $VM | select Name}

#Group 5.1
$VMLongArray51 = @()
$VMShortArray51 = @()

Write-Host "Retrieving list of servers in Group 5.1"
$VMAnnotation51 = Get-VM | Get-Annotation -CustomAttribute "Reboot Order" | Where {$_.value -eq "5.1"}

Write-Host "Organizing list, step 1"
ForEach ($VM in $VMAnnotation51) {$VMLongArray51 += $VM.AnnotatedEntity}

Write-Host "Organizing list, step 2"
ForEach ($VM in $VMLongArray51) {$VMShortArray51 += $VM | select Name}

#Group 4
$VMLongArray4 = @()
$VMShortArray4 = @()

Write-Host "Retrieving list of servers in Group 4"
$VMAnnotation4 = Get-VM | Get-Annotation -CustomAttribute "Reboot Order" | Where {$_.value -eq "4"}

Write-Host "Organizing list, step 1"
ForEach ($VM in $VMAnnotation4) {$VMLongArray4 += $VM.AnnotatedEntity}

Write-Host "Organizing list, step 2"
ForEach ($VM in $VMLongArray4) {$VMShortArray4 += $VM | select Name}

#Group 3
$VMLongArray3 = @()
$VMShortArray3 = @()

Write-Host "Retrieving list of servers in Group 3"
$VMAnnotation3 = Get-VM | Get-Annotation -CustomAttribute "Reboot Order" | Where {$_.value -eq "3"}

Write-Host "Organizing list, step 1"
ForEach ($VM in $VMAnnotation3) {$VMLongArray3 += $VM.AnnotatedEntity}

Write-Host "Organizing list, step 2"
ForEach ($VM in $VMLongArray3) {$VMShortArray3 += $VM | select Name}

#Group 2
$VMLongArray2 = @()
$VMShortArray2 = @()

Write-Host "Retrieving list of servers in Group 2"
$VMAnnotation2 = Get-VM | Get-Annotation -CustomAttribute "Reboot Order" | Where {$_.value -eq "2"}

Write-Host "Organizing list, step 1"
ForEach ($VM in $VMAnnotation2) {$VMLongArray2 += $VM.AnnotatedEntity}

Write-Host "Organizing list, step 2"
ForEach ($VM in $VMLongArray2) {$VMShortArray2 += $VM | select Name}

#Group 1.3
$VMLongArray13 = @()
$VMShortArray13 = @()

Write-Host "Retrieving list of servers in Group 1.3"
$VMAnnotation13 = Get-VM | Get-Annotation -CustomAttribute "Reboot Order" | Where {$_.value -eq "1.3"}

Write-Host "Organizing list, step 1"
ForEach ($VM in $VMAnnotation13) {$VMLongArray13 += $VM.AnnotatedEntity}

Write-Host "Organizing list, step 2"
ForEach ($VM in $VMLongArray13) {$VMShortArray13 += $VM | select Name}

#Group 1.2
$VMLongArray12 = @()
$VMShortArray12 = @()

Write-Host "Retrieving list of servers in Group 1.2"
$VMAnnotation12 = Get-VM | Get-Annotation -CustomAttribute "Reboot Order" | Where {$_.value -eq "1.2"}

Write-Host "Organizing list, step 1"
ForEach ($VM in $VMAnnotation12) {$VMLongArray12 += $VM.AnnotatedEntity}

Write-Host "Organizing list, step 2"
ForEach ($VM in $VMLongArray12) {$VMShortArray12 += $VM | select Name}

#Group 1.1
$VMLongArray11 = @()
$VMShortArray11 = @()

Write-Host "Retrieving list of servers in Group 1.1"
$VMAnnotation11 = Get-VM | Get-Annotation -CustomAttribute "Reboot Order" | Where {$_.value -eq "1.1"}

Write-Host "Organizing list, step 1"
ForEach ($VM in $VMAnnotation11) {$VMLongArray11 += $VM.AnnotatedEntity}

Write-Host "Organizing list, step 2"
ForEach ($VM in $VMLongArray11) {$VMShortArray11 += $VM | select Name}

###################################################################
#Wait and Verify                                                  #
###################################################################

Write-Host ""
Write-Host "Server groups have been obtained."
$Verify = Read-Host "Are you sure you want to proceed with restart? (type 'yes' to continue)"

if ($Verify -ne "yes")
{
	exit
}

###################################################################
#Shut down VM's by Group                                          #
###################################################################

#Shut down Group 5.3====================================================
Write-Host "Shutting down VM's in Group 5.3"
ForEach ($VM in $VMShortArray53) {Shutdown-VMGuest -VM $VM.Name -Confirm:$false}

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	ForEach ($VM in $VMShortArray53)
	{
		$Check = (Get-VM -Name $VM.Name | select PowerState)
		if ($Check.PowerState -eq "PoweredOn")
			{
				$NotOffYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM shut down not complete..."
}
Write-Host ""
Write-Host "VM's in Group 5.3 have been shut down."

#End Group 5.3====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Shut down Group 5.2====================================================
Write-Host "Shutting down VM's in Group 5.2"
ForEach ($VM in $VMShortArray52) {Shutdown-VMGuest -VM $VM.Name -Confirm:$false}

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	ForEach ($VM in $VMShortArray52)
	{
		$Check = (Get-VM -Name $VM.Name | select PowerState)
		if ($Check.PowerState -eq "PoweredOn")
			{
				$NotOffYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM shut down not complete..."
}
Write-Host ""
Write-Host "VM's in Group 5.2 have been shut down."

#End Group 5.2====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Shut down Group 5.1====================================================
Write-Host "Shutting down VM's in Group 5.1"
ForEach ($VM in $VMShortArray51) {Shutdown-VMGuest -VM $VM.Name -Confirm:$false}

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	ForEach ($VM in $VMShortArray51)
	{
		$Check = (Get-VM -Name $VM.Name | select PowerState)
		if ($Check.PowerState -eq "PoweredOn")
			{
				$NotOffYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM shut down not complete..."
}
Write-Host ""
Write-Host "VM's in Group 5.1 have been shut down."

#End Group 5.1====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Shut down Group 4====================================================
Write-Host "Shutting down VM's in Group 4"
ForEach ($VM in $VMShortArray4) {Shutdown-VMGuest -VM $VM.Name -Confirm:$false}

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	ForEach ($VM in $VMShortArray4)
	{
		$Check = (Get-VM -Name $VM.Name | select PowerState)
		if ($Check.PowerState -eq "PoweredOn")
			{
				$NotOffYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM shut down not complete..."
}
Write-Host ""
Write-Host "VM's in Group 4 have been shut down."

#End Group 4====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Shut down Group 3====================================================
Write-Host "Shutting down VM's in Group 3"
ForEach ($VM in $VMShortArray3) {Shutdown-VMGuest -VM $VM.Name -Confirm:$false}

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	ForEach ($VM in $VMShortArray3)
	{
		$Check = (Get-VM -Name $VM.Name | select PowerState)
		if ($Check.PowerState -eq "PoweredOn")
			{
				$NotOffYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM shut down not complete..."
}
Write-Host ""
Write-Host "VM's in Group 3 have been shut down."

#End Group 3====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Shut down Group 2====================================================
Write-Host "Shutting down VM's in Group 2"
ForEach ($VM in $VMShortArray2) {Shutdown-VMGuest -VM $VM.Name -Confirm:$false}

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	ForEach ($VM in $VMShortArray2)
	{
		$Check = (Get-VM -Name $VM.Name | select PowerState)
		if ($Check.PowerState -eq "PoweredOn")
			{
				$NotOffYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM shut down not complete..."
}
Write-Host ""
Write-Host "VM's in Group 2 have been shut down."

#End Group 2====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Shut down Group 1.3====================================================
Write-Host "Shutting down VM's in Group 1.3"
ForEach ($VM in $VMShortArray13) {Shutdown-VMGuest -VM $VM.Name -Confirm:$false}

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	ForEach ($VM in $VMShortArray13)
	{
		$Check = (Get-VM -Name $VM.Name | select PowerState)
		if ($Check.PowerState -eq "PoweredOn")
			{
				$NotOffYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM shut down not complete..."
}
Write-Host ""
Write-Host "VM's in Group 1.3 have been shut down."

#End Group 1.3====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Shut down Group 1.2====================================================
Write-Host "Shutting down VM's in Group 1.2"
ForEach ($VM in $VMShortArray12) {Shutdown-VMGuest -VM $VM.Name -Confirm:$false}

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	ForEach ($VM in $VMShortArray12)
	{
		$Check = (Get-VM -Name $VM.Name | select PowerState)
		if ($Check.PowerState -eq "PoweredOn")
			{
				$NotOffYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM shut down not complete..."
}
Write-Host ""
Write-Host "VM's in Group 1.2 have been shut down."

#End Group 1.2====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Shut down Group 1.1====================================================
Write-Host "Shutting down VM's in Group 1.1"
ForEach ($VM in $VMShortArray11) {Shutdown-VMGuest -VM $VM.Name -Confirm:$false}

$NotOffYet = "true"

while ($NotOffYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOffYet = "false"
	ForEach ($VM in $VMShortArray11)
	{
		$Check = (Get-VM -Name $VM.Name | select PowerState)
		if ($Check.PowerState -eq "PoweredOn")
			{
				$NotOffYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM shut down not complete..."
}
Write-Host ""
Write-Host "VM's in Group 1.1 have been shut down."

#End Group 1.1====================================================

###################################################################
#End Shutdown VM's by Group                                       #
###################################################################

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $StartDelay

###################################################################
#Power On VM's by group                                           #
###################################################################

#Power On Group 1.1=====================================================
Write-Host "Starting up VM's in Group 1.1"
ForEach ($VM in $VMShortArray11) {Start-VM -VM $VM.Name}

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	ForEach ($VM in $VMShortArray11)
	{
		$Check = (Get-VM -Name $VM.Name | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
		if ($Check.ToolsStatus -eq "toolsNotRunning")
			{
				$NotOnYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM start up not complete..."
}
Write-Host ""
Write-Host "VM's in Group 1.1 have been started up."

#End Group 1.1====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Power On Group 1.2=====================================================
Write-Host "Starting up VM's in Group 1.2"
ForEach ($VM in $VMShortArray12) {Start-VM -VM $VM.Name}

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	ForEach ($VM in $VMShortArray12)
	{
		$Check = (Get-VM -Name $VM.Name | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
		if ($Check.ToolsStatus -eq "toolsNotRunning")
			{
				$NotOnYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM start up not complete..."
}
Write-Host ""
Write-Host "VM's in Group 1.2 have been started up."

#End Group 1.2====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Power On Group 1.3=====================================================
Write-Host "Starting up VM's in Group 1.3"
ForEach ($VM in $VMShortArray13) {Start-VM -VM $VM.Name}

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	ForEach ($VM in $VMShortArray13)
	{
		$Check = (Get-VM -Name $VM.Name | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
		if ($Check.ToolsStatus -eq "toolsNotRunning")
			{
				$NotOnYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM start up not complete..."
}
Write-Host ""
Write-Host "VM's in Group 1.3 have been started up."

#End Group 1.3====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Power On Group 2=====================================================
Write-Host "Starting up VM's in Group 2"
ForEach ($VM in $VMShortArray2) {Start-VM -VM $VM.Name}

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	ForEach ($VM in $VMShortArray2)
	{
		$Check = (Get-VM -Name $VM.Name | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
		if ($Check.ToolsStatus -eq "toolsNotRunning")
			{
				$NotOnYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM start up not complete..."
}
Write-Host ""
Write-Host "VM's in Group 2 have been started up."

#End Group 2====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Power On Group 3=====================================================
Write-Host "Starting up VM's in Group 3"
ForEach ($VM in $VMShortArray3) {Start-VM -VM $VM.Name}

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	ForEach ($VM in $VMShortArray3)
	{
		$Check = (Get-VM -Name $VM.Name | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
		if ($Check.ToolsStatus -eq "toolsNotRunning")
			{
				$NotOnYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM start up not complete..."
}
Write-Host ""
Write-Host "VM's in Group 3 have been started up."

#End Group 3====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Power On Group 4=====================================================
Write-Host "Starting up VM's in Group 4"
ForEach ($VM in $VMShortArray4) {Start-VM -VM $VM.Name}

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	ForEach ($VM in $VMShortArray4)
	{
		$Check = (Get-VM -Name $VM.Name | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
		if ($Check.ToolsStatus -eq "toolsNotRunning")
			{
				$NotOnYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM start up not complete..."
}
Write-Host ""
Write-Host "VM's in Group 4 have been started up."

#End Group 4====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Power On Group 5.1=====================================================
Write-Host "Starting up VM's in Group 5.1"
ForEach ($VM in $VMShortArray51) {Start-VM -VM $VM.Name}

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	ForEach ($VM in $VMShortArray51)
	{
		$Check = (Get-VM -Name $VM.Name | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
		if ($Check.ToolsStatus -eq "toolsNotRunning")
			{
				$NotOnYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM start up not complete..."
}
Write-Host ""
Write-Host "VM's in Group 5.1 have been started up."

#End Group 5.1====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Power On Group 5.2=====================================================
Write-Host "Starting up VM's in Group 5.2"
ForEach ($VM in $VMShortArray52) {Start-VM -VM $VM.Name}

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	ForEach ($VM in $VMShortArray52)
	{
		$Check = (Get-VM -Name $VM.Name | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
		if ($Check.ToolsStatus -eq "toolsNotRunning")
			{
				$NotOnYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM start up not complete..."
}
Write-Host ""
Write-Host "VM's in Group 5.2 have been started up."

#End Group 5.2====================================================

Write-Host ""
Write-Host "Waiting for everything to settle down..."
Write-Host ""
start-sleep -s $SettleDelay

#Power On Group 5.3=====================================================
Write-Host "Starting up VM's in Group 5.3"
ForEach ($VM in $VMShortArray53) {Start-VM -VM $VM.Name}

$NotOnYet = "true"

while ($NotOnYet -eq "true") 
{
	start-sleep -s $CheckDelay
	$NotOnYet = "false"
	ForEach ($VM in $VMShortArray53)
	{
		$Check = (Get-VM -Name $VM.Name | Get-View | Select-Object @{Name="ToolsStatus";E={$_.Guest.ToolsStatus}})
		if ($Check.ToolsStatus -eq "toolsNotRunning")
			{
				$NotOnYet = "true"
			}
	}
	Write-Host ""
	Write-Host "VM start up not complete..."
}
Write-Host ""
Write-Host "VM's in Group 5.3 have been started up."

#End Group 5.3====================================================

###################################################################
#End Power On VM's by group                                       #
###################################################################