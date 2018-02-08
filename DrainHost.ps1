[CmdletBinding()]
Param(
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath

. .\Functions\function_Check-PowerCLI.ps1
. .\Functions\function_Connect-vCenter.ps1
. .\Functions\Function_DoLogging.ps1

Check-PowerCLI
Connect-vCenter

if ($Cluster_Name -eq $NULL) { $Cluster_Name = Read-Host "What is the name of the cluster?" }

$Cluster = Get-Cluster $Cluster_Name

if ($Cluster -eq $NULL) { Write-Host "Cluster name does not exist..."; exit }

if ($($Cluster.DrsEnabled))
{
	$Stored_DRS_Level = $Cluster.DrsAutomationLevel
	Set-Cluster -Cluster $Cluster -DrsAutomationLevel Manual -Confirm:$false
}

$Hosts_In_Cluster = Get-Cluster $Cluster | Get-VMHost | Sort-Object Name

$i = 1

$Hosts_In_Array = @()
cls

foreach ($Host_In_Cluster in $Hosts_In_Cluster)
{
	$Hosts_In_Array += New-Object -Type PSObject -Property (@{
		Identifyer = $i
		HostName = $Host_In_Cluster.Name
		MemPercent = $Host_In_Cluster.MemoryUsageGB / $Host_In_Cluster.MemoryTotalGB
	})
	$i++
}

foreach ($Host_In_Array in $Hosts_In_Array)
{
	Write-Host $("`t`t"+$Host_In_Array.Identifyer+".`t"+$Host_In_Array.HostName)
}

$Selection = Read-Host "Please select the host you would like to drain"

$Host_To_Drain = $Hosts_In_Array[$Selection - 1]

$Hosts_Minus_One = $Hosts_In_Array | Where-Object { $_.HostName -ne $Host_To_Drain.HostName }

$VMs_To_Migrate = Get-VMHost $Host_To_Drain.HostName | Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}
$VMs_To_Migrate_Count = $VMs_To_Migrate.Count
$VMc = 1

foreach ($VM_To_Migrate in $VMs_To_Migrate)
{
	Write-Progress -Activity "Migrating VMs..." -Status "Moving VM $VMc of $VMs_To_Migrate_Count" -PercentComplete ($VMc / $VMs_To_Migrate_Count*100)

	$Hosts_Minus_One = $Hosts_Minus_One | Sort-Object MemPercent

	Move-VM -VM $VM_To_Migrate -Destination $Hosts_Minus_One[0].HostName

	foreach ($Host_Minus_One in $Hosts_Minus_One)
	{
		$HostInfo = Get-VMHost $Host_Minus_One.HostName
		$NewMemPercent = $HostInfo.MemoryUsageGB / $HostInfo.MemoryTotalGB
		$Rec = $Hosts_Minus_One | Where-Object {$_.HostName -eq $Host_Minus_One.HostName}
		$Rec.MemPercent = $NewMemPercent
	}
	$VMc++
}

Set-Cluster -Cluster $Cluster -DrsAutomationLevel FullyAutomated -Confirm:$false

Set-VMHost -VMHost $Host_To_Drain.HostName -State Maintenance -Evacuate:$true

Set-Cluster -Cluster $Cluster -DrsAutomationLevel $Stored_DRS_Level -Confirm:$false