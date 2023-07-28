<#
What does the script do?
Evacuates an ESX host one VM at a time, puts the host in maintenance mode and uses all attached update manager baseline groups to update the host.

Where/How does the script run?
The script can be run from anywhere that has access to connect to the vCenter server with the datastore cluster to be balanced.

What account do I run it with?
No specific account is needed. Your own login will work.

What is the syntax for executing?
PatchHost.ps1

What does this script need to function properly?
1. "DupreeFunctions" PowerShell module in a path that is listed in the PSModulePath environment variable. I recommend "%ProgramFiles%\WindowsPowerShell\Modules".
2. PowerCLI must be installed.
3. ESX host to be updated must have at least one baseline attached in update manager.
#>

[CmdletBinding()]
Param(
)
 
$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
$ErrorActionPreference = "SilentlyContinue"
  
Function Check-PowerCLI
{
    Param(
    )
  
    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
        write-host ("Adding PowerCLI...")
        Get-Module -Name VMware* -ListAvailable | Import-Module -Global
        write-host ("Loaded PowerCLI.")
    }
}
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  
Check-PowerCLI
 
if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}
 
Connect-DFvCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

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