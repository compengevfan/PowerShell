$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL) { Write-Host "VMware Snapin Not Loaded..."; exit }

if ($global:DefaultVIServers.Count -eq 0) { Write-Host "Not Connected to a VCenter..."; exit }

if ($Cluster_Name -eq $NULL) { $Cluster_Name = Read-Host "What is the name of the cluster?" }

$Cluster = Get-Cluster $Cluster_Name

if ($Cluster -eq $NULL) { Write-Host "Cluster name does not exist..."; exit }

if ($($Cluster.DrsEnabled))
{
	$Stored_DRS_Level = $Cluster.DrsAutomationLevel
	Set-Cluster -Cluster $Cluster -DrsAutomationLevel Manual -Confirm:$false
}

$Hosts_In_Cluster = Get-Cluster $Cluster | Get-VMHost | Sort-Object Name

$i = 0

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

$Selection = Read-Host "Please select the host you would like to update"

$Host_To_Update = $Hosts_In_Array[$Selection]

$Hosts_Minus_One = $Hosts_In_Array | Where-Object { $_.HostName -ne $Host_To_Update.HostName }

$VMs_To_Migrate = Get-VMHost $Host_To_Update.HostName | Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}
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

Set-VMHost -VMHost $Host_To_Update.HostName -State Maintenance -Evacuate:$true

Set-Cluster -Cluster $Cluster -DrsAutomationLevel $Stored_DRS_Level -Confirm:$false

Scan-Inventory -Entity $Host_To_Update.HostName

$NC_Baselines = Get-Compliance -Entity $Host_To_Update.HostName -ComplianceStatus NotCompliant

foreach ($NC_Baseline in $NC_Baselines)
{
	$Working_Baseline = Get-Baseline $NC_Baseline.Baseline.Name
	Stage-Patch -Entity $Host_To_Update.HostName -Baseline $Working_Baseline
	Remediate-Inventory -Entity $Host_To_Update.HostName -Baseline $Working_Baseline -ClusterDisableDistributedPowerManagement:$true -Confirm:$false
}