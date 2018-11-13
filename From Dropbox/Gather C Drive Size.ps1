#Get list of Servers
$Computers = "C:\ScriptOutput\Computers.txt"
if (Test-Path $Computers) { del $Computers }

$VMs = Get-VM | where {($_.vmhost.parent.name -eq "LCC_Test") -or ($_.vmhost.parent.name -eq "Prod_BU")} | where {$_.PowerState -eq "PoweredOn"} | where {($_.Name -like "*SQL*") -and ($_.Name -notlike "*LC3*")} | Sort-Object Name

foreach ($VM in $VMs)
{
	$VM.extensiondata.guest.hostname | Out-File -append $Computers
}

#Use WMI to get C drive size information
$DriveSpace = "C:\ScriptOutput\DriveSpace.txt"
if (Test-Path $DriveSpace) { del $DriveSpace }

$servers = Get-Content C:\ScriptOutput\Computers.txt

foreach ($server in $servers)
{
	Get-WMIObject Win32_LogicalDisk -filter “DeviceID='C:'" -computer $server | Select SystemName,DeviceID,@{Name="Size(GB)";Expression={[decimal](“{0:N1}" -f($_.size/1gb))}},@{Name="Free Space(GB)";Expression={[decimal](“{0:N1}" -f($_.freespace/1gb))}},@{Name="Free Space(%)";Expression={“{0:P2}" -f(($_.freespace/1gb) / ($_.size/1gb))}} | Out-File -Append $DriveSpace
}

#Use WMI to verify C greater than or equal to 19312922624 bytes.
$TooSmall = "C:\ScriptOutput\TooSmall.txt"
if (Test-Path $TooSmall) { del $TooSmall }

$servers = Get-Content C:\ScriptOutput\Computers.txt

foreach ($server in $servers)
{
	$Size = Get-WMIObject Win32_LogicalDisk -filter "DeviceID='C:'" -computer $server | select Size
	
	if ($Size.Size -lt 19312922624)
	{
		$server | Out-File -Append $TooSmall
	}
}