[CmdletBinding()]
Param(
)

#Import functions
. .\Functions\function_Check-PowerCLI.ps1
. .\Functions\function_Connect-vCenter.ps1

Check-PowerCLI

Connect-vCenter

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