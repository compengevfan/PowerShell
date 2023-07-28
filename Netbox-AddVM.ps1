[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [string] $VMName,
    [Parameter(Mandatory = $true)] [string] $VMDomainName,
    [Parameter(Mandatory = $true)] [int16] $vCPUs,
    [Parameter(Mandatory = $true)] [int16] $RAM,
    [Parameter(Mandatory = $true)] [int16] $Disk,
    [Parameter(Mandatory = $true)] [string] $IpAddress,
    [Parameter(Mandatory = $true)] [pscredential] $Credential
)

Import-Module DupreeFunctions

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$Header = Invoke-DfNetboxGetHeader -Credential $Credential

$ReturnJSON = Invoke-DfNetboxAddVm -VMName $VMName -vCPUs $vCPUs -RAM $RAM -Disk $Disk -header $Header
$Return = $ReturnJSON | ConvertFrom-Json
$VmId = $Return.id

$ReturnJSON = Invoke-DfNetboxAddVmInterface -VmId $VmId -header $Header
$Return = $ReturnJSON | ConvertFrom-Json
$AssignedObjectId = $Return.id

$ReturnJSON = Invoke-DfNetboxAddIp -IpAddress $IpAddress -AssignedObjectId $AssignedObjectId -DnsName $( $VMName + "." + $VMDomainName) -header $Header
$Return = $ReturnJSON | ConvertFrom-Json
$IpId = $Return.id

$ReturnJSON = Invoke-DfNetboxAddIpToVM -VmId $VmId -IpId $IpId -header $Header
$Return = $ReturnJSON | ConvertFrom-Json

