[CmdletBinding()]
param(
[parameter(Mandatory = $true,
		   ValueFromPipeline = $true,
		   ValueFromPipelineByPropertyName = $true)]
[string[]] $MacAddress
)

begin {
# $Regex contains the regular expression of a valid MAC address
$Regex = "^[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]$" 

# Get all the virtual machines
$VMsView = Get-View -ViewType VirtualMachine -Property Name,Guest.Net
}

process {
ForEach ($Mac in $MacAddress) {
  # Check if the MAC Address has a valid format
  if ($Mac -notmatch $Regex) {
	Write-Error "$Mac is not a valid MAC address. The MAC address should be in the format 99:99:99:99:99:99."
  }
  else {    
	# Get all the virtual machines
	$VMsView | `
	  ForEach-Object {
		$VMview = $_
		$VMView.Guest.Net | Where-Object {
		  # Filter the virtual machines on Mac address
		  $_.MacAddress -eq $Mac
		} | `
		  Select-Object -property @{N="VM";E={$VMView.Name}},
			MacAddress,
			IpAddress,
			Connected
	  }
  }
}
}