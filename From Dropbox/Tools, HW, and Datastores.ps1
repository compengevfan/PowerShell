New-VIProperty -Name ToolsVersionStatus -ObjectType VirtualMachine -ValueFromExtensionProperty 'Guest.ToolsVersionStatus' -Force

Get-VM | Select Name, Version, ToolsVersionStatus | Where-Object {$_.Version -ne "v8"} | FT -AutoSize
Get-VM | Select Name, Version, ToolsVersionStatus | Where-Object {$_.ToolsVersionStatus -ne "guestToolsCurrent"} | FT -AutoSize

New-VIProperty -Name VMFSVersion -ObjectType Datastore -Value {param($ds) $ds.ExtensionData.Info.Vmfs.Version} -Force

Get-Datastore | Select Name, VMFSVersion | Where-Object {$_.VMFSVersion -ne "5.54"}| FT -AutoSize