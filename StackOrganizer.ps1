[CmdletBinding()]
Param(
)

#Check for vCenter Server Connection
$ConnectedvCenterCount = $global:DefaultVIServers.Count

#Obtain info from user
if ($ConnectedvCenterCount -eq 0) { $vCenter = Read-Host -Prompt ("Please enter the name of the vCenter Server"); Connect-VIServer $vCenter }
$Cluster = Read-Host -Prompt ("Please enter the name of the cluster to be organized")

$ClusterHosts = Get-Cluster $Cluster | Get-VMHost | Sort-Object Name

$StackLayout = Import-Csv .\StackOrganizer-Layout.csv

foreach ($Record in $StackLayout)
{
    $NamePart = $Record.VM
    $HostNum = $($Record.Host) - 1

    $CurrentVM = Get-Cluster $Cluster | Get-VM | Where-Object { $_.Name -like "*$NamePart" }
    if ($CurrentVM -ne $null) { Move-VM -VM $CurrentVM -Destination $ClusterHosts[$HostNum] }
}