#Check for vCenter Server Connection
$ConnectedvCenterCount = $global:DefaultVIServers.Count

#Obtain info from user
if ($ConnectedvCenterCount -eq 0) { $vCenter = Read-Host -Prompt ("Please enter the name of the vCenter Server"); Connect-VIServer $vCenter }

$DatastoreCluster = Read-Host -Prompt ("Please enter the name of the datastore cluster to be balanced")

#Retrieve datastores from cluster
$DatastoresToBalance = Get-DatastoreCluster $DatastoreCluster | Get-Datastore | Sort-Object FreeSpaceGB

#Find datastore with least and most free space
$DSleastFree = $DatastoresToBalance | Select-Object -First 1
$DSmostFree = $DatastoresToBalance | Select-Object -Last 1

#Figure out if balancing needs to occur
$Space1 = $DSmostFree.FreeSpaceGB
$Space2 = $DSleastFree.FreeSpaceGB
$Diff = $Space1 - $Space2
if ($Diff -gt 200 -and $DatastoresToBalance.Count -gt 1) { $RunAgain = $true }
else
{
    $RunAgain = $false
    Write-Host ("Exiting script. Cluster is either balanced or only has 1 datastore")
}

while ($RunAgain)
{
    #Get list of VM on DS with least space and pick a random VM
    $SourceVMs = Get-VM -Datastore $DSleastFree.Name | Sort-Object Name
    $SourceVMCount = $SourceVMs.Count
    $RandomNumber = Get-Random -Maximum $SourceVMCount

    $VMtoMove = $SourceVMs[$RandomNumber]

    $Supress = Move-VM -VM $VMtoMove -Datastore $DSmostFree.Name -Confirm:$false
    Write-Host ("Migrated $($VMtoMove.Name) from $($DSleastFree.Name) to $($DSmostFree.Name).")

    #Retrieve datastores from cluster
    $DatastoresToBalance = Get-DatastoreCluster $DatastoreCluster | Get-Datastore | Sort-Object FreeSpaceGB

    #Find datastore with least and most free space
    $DSleastFree = $DatastoresToBalance | Select-Object -First 1
    $DSmostFree = $DatastoresToBalance | Select-Object -Last 1

    #Figure out if balancing needs to occur
    $Space1 = $DSmostFree.FreeSpaceGB
    $Space2 = $DSleastFree.FreeSpaceGB
    $Diff = $Space1 - $Space2
    if ($Diff -lt 200)
    {
        $RunAgain = $false
        Write-Host ("Script complete. Cluster is now balanced.")
    }
}