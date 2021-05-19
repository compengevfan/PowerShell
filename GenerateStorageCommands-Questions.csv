[CmdletBinding()]
Param(
)

$Replication = Read-Host "Is replication required? (y/n)"
$LocalSID = Read-Host "Please provide the SID for the array. (ex: 0916)"
$DeviceCapacity = Read-Host "Please provide the disk size (number only)"
$CapType = Read-Host "Please provide the capacity multiplier (gb or tb)"
$DeviceCount = Read-Host "How many devices are needed?"
$StorageGroup = Read-Host "What is the name of the storage group? (symsg -sid $LocalSID list | grep [Server Name]"

if ($Replication -eq "y")
{
    $RemoteSID = Read-Host "What is the SID for the remote array?"
    $StorageGroupR2 = Read-Host "What is the name of the R2 group?"
    $StorageGroupVX = $StorageGroupR2.Replace("_R2", "_VX")
}