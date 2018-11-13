$DataStores = Get-DataStore *LUN*

ForEach ($DataStore in $DataStores)
{
	$VMList = $DataStore.ExtensionData.vm
	
	$Count = $VMList.count
	
	if ($Count -gt 10)
	{
		write-host ($DataStore.Name + " " + $Count)
	}
}
