<#
What does the script do?
Balances VM workload across the hosts in a vCenter cluster.

Where/How does the script run?
The script can be run from anywhere that has access to connect to the vCenter server with the cluster to be balanced.

What account do I run it with?
No specific account is needed. Your own login will work.

What is the syntax for executing?
BalanceDatastoreSpace.ps1

What does this script need to function properly?
1. "DupreeFunctions" PowerShell module in a path that is listed in the PSModulePath environment variable. I recommend "%ProgramFiles%\WindowsPowerShell\Modules".
2. PowerCLI must be installed.
#>

[CmdletBinding()]
Param(
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath

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

Check-PowerCLI
Connect-vCenter

$Cluster = Read-Host -Prompt ("Please enter the name of the cluster to be balanced")
#Retrieve hosts from cluster
$HostsToBalance = Get-Cluster $Cluster | Get-VMHost | ? {$_.ConnectionState -eq "Connected"} | Sort-Object MemoryUsageGB

#Find datastore with least and most free space
$HostLeastUsed = $HostsToBalance | Select-Object -First 1
$HostMostUsed = $HostsToBalance | Select-Object -Last 1

#Figure out if balancing needs to occur
$Space1 = $HostMostUsed.MemoryUsageGB
$Space2 = $HostLeastUsed.MemoryUsageGB
$Diff = $Space1 - $Space2
if ($Diff -gt 64 -and $HostsToBalance.Count -gt 1) { $RunAgain = $true }
else
{
    $RunAgain = $false
    Write-Host ("Exiting script. Cluster is either balanced or only has 1 host")
}

while ($RunAgain)
{
    #Get list of VM on DS with least space and pick a random VM
    $SourceVMs = Get-VMHost $HostMostUsed | Get-VM | Where-Object {$_.ExtensionData.Guest.GuestFullName -notlike "*Red Hat*"} | Sort-Object Name
    $SourceVMCount = $SourceVMs.Count
    $RandomNumber = Get-Random -Maximum $SourceVMCount

    $VMtoMove = $SourceVMs[$RandomNumber]

    $Supress = Move-VM -VM $VMtoMove -Destination $HostLeastUsed.Name -Confirm:$false
    Write-Host ("Migrated $($VMtoMove.Name) from $($HostMostUsed.Name) to $($HostLeastUsed.Name).")

    #Retrieve datastores from cluster
    $HostsToBalance = Get-Cluster $Cluster | Get-VMHost | ? {$_.ConnectionState -eq "Connected"} | Sort-Object MemoryUsageGB

    #Find datastore with least and most free space
    $HostLeastUsed = $HostsToBalance | Select-Object -First 1
    $HostMostUsed = $HostsToBalance | Select-Object -Last 1

    #Figure out if balancing needs to occur
    $Space1 = $HostMostUsed.MemoryUsageGB
    $Space2 = $HostLeastUsed.MemoryUsageGB
    $Diff = $Space1 - $Space2
    if ($Diff -lt 64)
    {
        $RunAgain = $false
        Write-Host ("Script complete. Cluster is now balanced.")
    }
}