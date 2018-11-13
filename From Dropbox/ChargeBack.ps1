write-host("Retrieving list of VMs...")
$VMs = Get-VM

[int] $TotalCPUs = 0
[int] $TotalMemory = 0
[int] $TotalProStorage = 0
[int] $TotalUsedStorage = 0

$TempString = ""
$Date = Get-Date -Format "MM-dd-yyyy"
$FileLocation = "C:\ScriptOutput\Charge Back " + $Date + ".txt"

$Products = @()

#Gather list of Business Units

foreach ($VM in $VMs) 
{
	$CustomFields = $VM.CustomFields | select Key, Value
	$CustomField = $CustomFields | where {$_.Key -eq "Product"}
	
	if (($Products -notcontains $CustomField.Value) -and ($CustomField.Value -ne ""))
	{
		$Products += $CustomField.Value
	}
}

#Go through each Business Unit and get a count of CPU's, memory and storage.

foreach ($Product in $Products)
{	
	write-host ("Processing Product " + $Product + ".")
	foreach ($VM in $VMs)
	{
		$CustomFields = $VM.CustomFields | select Key, Value
		$CustomField = $CustomFields | where {$_.Key -eq "Product"}
		if ($CustomField.Value -eq $Product)
		{
			$TotalCPUs += $VM.NumCPU
			$TotalMemory += $VM.MemoryMB
			$TotalProStorage += $VM.ProvisionedSpaceGB
			$TotalUsedStorage += $VM.UsedSpaceGB
		}
	}
		
	$TempString = "Product: " + $Product
	$TempString | out-file $FileLocation -append
	$TempString = "CPUs: " + $TotalCPUs
	$TempString | out-file $FileLocation -append
	$TempString = "Memory: " +$TotalMemory + "MB"
	$TempString | out-file $FileLocation -append
	$TempString = "Used Storage: " +$TotalUsedStorage+ "GB"
	$TempString | out-file $FileLocation -append
	$TempString = "Provisioned Storage: " +$TotalProStorage+ "GB"
	$TempString | out-file $FileLocation -append
	$TempString = ""
	$TempString | out-file $FileLocation -append
	$TempString = "=================================="
	$TempString | out-file $FileLocation -append
	$TempString = ""
	$TempString | out-file $FileLocation -append
	
	$TotalCPUs = 0
	$TotalMemory = 0
	$TotalProStorage = 0
	$TotalUsedStorage = 0
}

write-host("")
write-host ("Data written to " + $FileLocation + ".")