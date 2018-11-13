# Environment Setup
$DNSServer = "YourDNSServer"
$DNSZone = "YourZoneName"
$InputFile = "dnsrecords.csv"

# Read the input file which is formatted as name,type,address with a header row
$records = Import-CSV $InputFile

# Now we loop through the file to delete and re-create records
# DNSCMD does not have a modify option so we must use /RecordDelete first followed by a /RecordAdd 

ForEach ($record in $records) {

	# Capture the record contents as variables
	$recordName = $record.name
	$recordType = $record.type
	$recordAddress = $record.address

	# Build our DNSCMD DELETE command syntax
	$cmdDelete = "dnscmd $DNSServer /RecordDelete $DNSZone $recordName $recordType /f"

	# Build our DNSCMD ADD command syntax
	$cmdAdd = "dnscmd $DNSServer /RecordAdd $DNSZone $recordName $recordType $recordAddress"

	# Now we execute the command
	Write-Host "Running the following command: $cmdDelete"
	Invoke-Expression $cmdDelete

	Write-Host "Running the following command: $cmdAdd"
	Invoke-Expression $cmdAdd
}