Import-Module "G:\Software\PS_SDK\DellStorage.ApiCommandSet.psd1"

$Connection = Connect-DellApiConnection -HostName localhost

$StorageCenter = Get-DellStorageCenter -Connection $Connection | where {$_.instancename -eq "JAXF-CMLSC8K"}

$Volumes = Get-DellScVolume -StorageCenter $StorageCenter -Connection $Connection

foreach ($Volume in $Volumes)
{
	
}


$StorageCenter = Get-DellStorageCenter -Connection $Connection | where {$_.instancename -eq "JAXF-CMLSC8K"}

$VolumeConfigs = Get-DellScVolumeConfiguration -StorageCenter $StorageCenter -Connection $Connection

foreach ($VolumeConfig in $VolumeConfigs)
{
	Set-DellScVolumeConfiguration -Instance $VolumeConfig -ReplayCreationPaused $True -Connection $Connection
}

foreach ($VolumeConfig in $VolumeConfigs)
{
	Set-DellScVolumeConfiguration -Instance $VolumeConfig -ReplayCreationPaused $false -Connection $Connection
}