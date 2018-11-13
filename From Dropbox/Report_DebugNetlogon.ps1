#version 0.1
#Initial release

Param(
[Parameter(Mandatory=$false)][System.String]$LocalPath="C:\temp\ad")

cls

If (Test-Path $LocalPath) {
	Write-Host -ForegroundColor Yellow "Local path, $LocalPath, exists, script will continue..."
	}
Else {
	Write-Host -ForegroundColor Yellow "Neither the specified or default path, $LocalPath, exist. Script will exit"
	exit
	}
	

#Extract Entire IP v4 address (A.B.C.D)
Function ExtractValidIPAddress($String){
    $IPregex=‘(?<Address>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))’
    If ($String -Match $IPregex) {$Matches.Address}
} 

#Extract 1st Octet of IP v4 address (A)
Function Extract1IPOctet($String){
    $IPregex=‘(?<Address>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)))’
    If ($String -Match $IPregex) {$Matches.Address}
}

#Extract 1st and 2nd Octet of IP v4 address (A.B)
Function Extract2IPOctet($String){
    $IPregex=‘(?<Address>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){1}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))’
    If ($String -Match $IPregex) {$Matches.Address}
}

#Extract 1st, 2nd and 3rd Octet of IP v4 address (A.B.C)
Function Extract3IPOctet($String){
    $IPregex=‘(?<Address>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){2}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))’
    If ($String -Match $IPregex) {$Matches.Address}
}

#Get list of all GCs in the forest
$DCs = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().GlobalCatalogs | select Name,Domain

#copy files from remote systems locally to the machine where script runs
$k = $null
foreach ($dc in $DCs) {
	$k++
	Write-Progress -activity "Copying NetLogon Logs from DCs to local path:" -status "Percent Done: " `
	-PercentComplete (($k / $DCs.Count)  * 100) -CurrentOperation "Copying LogFile from host $($dc.Name)"
	copy -path "\\$($dc.Name)\c`$\Windows\debug\netlogon.log" "C:\Temp\AD\netlogon\$($dc.Name).log" -erroraction:silentlycontinue | out-null
}

read-host "Press Enter to continue"

#Now parse each file and get only the unique IP Addresses
$Report = @()
$Logs = dir "c:\Temp\AD\netlogon\*.log"
$i = $null
ForEach ($log in $Logs) {
	$i++
	Write-Progress -activity "Now Processing Directory where all Netlogon Files are stored:" -status "Percent Done: " `
	-PercentComplete (($i / $Logs.Count)  * 100) -CurrentOperation "Getting LogFile for host $($Log.BaseName)"
	$importString = Import-Csv $log -Delimiter ' ' -Header Date,Time,Domain,Error,ComputerName,IPAddress
	$j = $null
	$importString | select Date,Time,ComputerName,IPAddress | sort IPAddress -Unique | % {
		$j++
		Write-Progress -activity "Now Processing NetLogonFiles" -status "Percent added: " `
		-PercentComplete (($j / $importString.Count)  * 100) -CurrentOperation "Adding $($_.IPAddress) to final Report"
		$row = "" | select DCName,Date,Time,ComputerName,IPAddress,Octet1,Octet12,Octet123
		$row.DCName = $log.basename
		$row.Date = $_.Date
		$row.Time = $_.Time
		$row.ComputerName = $_.ComputerName
		$row.IPAddress = ExtractValidIPAddress $_.IPAddress
		$row.Octet1 = Extract1IPOctet $row.IPAddress
		$row.Octet12 = Extract2IPOctet $row.IPAddress
		$row.Octet123 = Extract3IPOctet $row.IPAddress
		$Report += $row
		}
}

#Export the file to CSV, but before that, filter for unique entries, again
$fileName = "c:\temp\ad\netlogon\NetLogonUnique_" + (get-date -uformat "%d.%m.%Y-%H.%M.%S")+ ".csv"
$Report | sort IPAddress -Unique | Export-CSV -UseCulture -NoTypeInformation $fileName