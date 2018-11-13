﻿Function Get-FreeVDSPort ($VDSPG) {
	$nicTypes = "VirtualE1000","VirtualE1000e","VirtualPCNet32","VirtualVmxnet","VirtualVmxnet2","VirtualVmxnet3" 
	$ports = @{}

	# Get all the portkeys on the portgroup  
	$VDSPG.ExtensionData.PortKeys | Foreach {
		$ports.Add($_,$VDSPG.Name)
	}

	# Remove the portkeys in use  Get-View 
	$VDSPG.ExtensionData.Vm | Foreach {
	    $VMView = Get-View $_
		$nic = $VMView.Config.Hardware.Device | where {$nicTypes -contains $_.GetType().Name -and $_.Backing.GetType().Name -match "Distributed"}
	    $nic | where {$_.Backing.Port.PortKey} | Foreach {$ports.Remove($_.Backing.Port.PortKey)}
	}

	# Assign the first free portkey 
	if ($ports.Count -eq 0) {
		$null
	} Else {
		$ports.Keys | Select -First 1
	}
}

Function Set-VDSPGNumPorts ($VDSPG, $NumPorts) {	
	$spec = New-Object VMware.Vim.DVPortgroupConfigSpec
    $spec.numPorts = $NumPorts
	$spec.ConfigVersion = $VDSPG.ExtensionData.Config.Configversion
    $VDSPG.ExtensionData.ReconfigureDVPortgroup($spec)
}


Function Test-VDSVMIssue {
	Param (
		[parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [PSObject[]]$VM,
		[switch]$Fix
	)
	Process {
		Foreach ($VMachine in $VM){
			Foreach ($NA in ($VMachine | Get-NetworkAdapter)) {
				$VMName = $VMachine.Name
				If (($NA.ExtensionData.Backing.GetType()).Name -eq "VirtualEthernetCardDistributedVirtualPortBackingInfo") {
					$PortKey = $NA.ExtensionData.Backing.Port.PortKey
					$vSwitchID = $NA.ExtensionData.Backing.Port.SwitchUUID
					$Datastore = (($VMachine.ExtensionData.Config.Files.VmPathName).split("]")[0]).Replace("[","")
					$filename = "$($datastore):\.dvsData\$vSwitchID\$PortKey"
					if (-not (Get-PSDrive $datastore -ErrorAction SilentlyContinue)) {
						$NewDrive = New-PSDrive -Name $Datastore -Location (Get-Datastore $Datastore) -PSProvider VimDatastore -Root '\'
					}
					$filecheck = Get-ChildItem -Path $filename -ErrorAction SilentlyContinue
					if ($filecheck) {
						Write-Host -ForegroundColor Green "$VMName $($NA.Name) is OK"
					} Else {
						If ($Fix) 
						{
							Set-NetworkAdapter -NetworkAdapter $NA -NetworkName "VLAN605" -Confirm:$false
							Set-NetworkAdapter -NetworkAdapter $NA -NetworkName "VLAN600" -Confirm:$false
							Write-Host -ForegroundColor Green "$VMName $($NA.Name) is fixed."
						}
					}
				} Else {
					Write-Host -ForegroundColor Green "$VMName is not connected to a dvSwitch so this issue is not relevant."
				}
			}
		}
		Get-PSDrive | Where { ($_.Provider -like "*VimDatastore") -and ( $_.Name -notlike "*vmstore*")} | Foreach {
			Remove-PSDrive $_ | Out-Null
		}
	}
}


# Example code to check all VMs attached to vCenter for the issue:
# Get-VM | Test-VDSVMIssue

# Example code to fix all VMs attached to vCenter:
# Get-VM | Test-VDSVMIssue -Fix

# Example code to fix all VMs in Cluster01 for the issue:
# Get-Cluster01 | Get-VM | Test-VDSVMIssue

# Example code to fix all VMs in Cluster01:
# Get-Cluster01 | Get-VM | Test-VDSVMIssue -Fix


