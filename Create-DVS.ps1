<#
Script: Create-DVS.ps1
Author: Joe Titra
Version: 0.1
Description: Creates DVS in vCenter. Only for 10gb configuration
.EXAMPLE
  PS> .\Create-DVS -datacenter <datacenter>
#>
[cmdletbinding()]
Param (
    $datacenter,
    $ErrorActionPreference = "Stop"
)

function drawMenu($options,$verbiage){
    Write-Host "CSX ESXi DVS Creation Utility"
    Write-Host "Choose the $verbiage for the new distributed switch."
    Write-Host ""
    $count = 1
    foreach($option in $options){
        Write-Host "$count. $option"
        $count++
    }
    Write-Host ""
    $option = Read-Host "1-$($count-1), exit"
    return ($option -1)
}

try{$datacenter = Get-Datacenter $datacenter}
catch{throw "Couldn't find a datacenter named: $datacenter"}

#Import Port Groups and prompt for user input
$dvsCSV = Import-Csv ($env:githome + "\powershell\etc\Create-DVS-PortGroups.csv")
$environmentLevelChoice = drawMenu ($dvsCSV.EnvironmentLevel | Select-Object -Unique) "environment level"
$environmentLevel = ($dvsCSV.EnvironmentLevel | Select-Object -Unique)[$environmentLevelChoice]
$environmentChoice = drawMenu ($dvsCSV.Environment | Select-Object -Unique) "environment"
$environment = ($dvsCSV.Environment | Select-Object -Unique)[$environmentChoice]
$siteChoice = drawMenu ($dvsCSV.Site | Select-Object -Unique) "site"
$site = ($dvsCSV.Site | Select-Object -Unique)[$siteChoice]
$portGroups = $dvsCSV | where{$_.EnvironmentLevel -eq $environmentLevel -and $_.Environment -eq $environment -and $_.Site -eq $site}
$dvsName = "$($environment.ToUpper())_$($site)_$((Get-Culture).TextInfo.ToTitleCase($environmentLevel.ToLower()))_DVS"

#Validate
Write-Host "A new DVS will be created in datacenter: $datacenter with the name: $dvsName"
Write-Host "The following PortGroups will be created on the new DVS" -ForegroundColor "Yellow"
$portGroups | Select-Object PortGroup, VLAN | Format-Table -AutoSize
$response = (Read-Host "Would you like to continue? yes/no")
if($response -notlike "y*"){break}

#Create New Distributed Switch and associated Port Groups
$newDVS = New-VDSwitch -Name $dvsName -Location $datacenter -Version "6.0.0" -NumUplinkPorts 4 -LinkDiscoveryProtocol "CDP" -LinkDiscoveryProtocolOperation "Both" -Mtu 9000
foreach($portGroup in $portGroups){
    New-VDPortgroup -VDSwitch $newDVS -Name $portGroup.PortGroup -VlanId $portGroup.VLAN -NumPorts 128 -PortBinding "Static" -RunAsync
}