﻿[CmdletBinding()]
Param(
    [Parameter()] [bool] $Details = $false
)

#Import functions
. .\Functions\function_Check-PowerCLI.ps1
. .\Functions\function_Connect-vCenter.ps1

Check-PowerCLI

Connect-vCenter

cls

$ClusterToAnalize = Read-Host "Please enter the name of the cluster to be analized"

#Getting a list of hosts sorted by amount of physical RAM
$Hosts_In_Cluster = Get-Cluster -Name $ClusterToAnalize | Get-VMHost | Where-Object { $_.ConnectionState -eq "Connected" -and $_.PowerState -eq "PoweredOn" } | Sort-Object MemoryTotalGB -Descending

#Creating a host list without the host with the most physical RAM
$Hosts_Minus_One = $Hosts_In_Cluster | Where-Object { $_.Name -ne $($Hosts_In_Cluster[0].Name) }

#Calculate cluster available resources
$ClusterPCPUs = ($Hosts_Minus_One | Measure-Object NumCpu -Sum).Sum
$ClusterPRAM = ($Hosts_Minus_One | Measure-Object MemoryTotalGB -Sum).Sum

#Calculate virtual resources allocated
$ClusterVCPUs = 0
$ClusterVRAM = 0
foreach ($VMHost in $Hosts_In_Cluster)
{
    $VMHostTotalPoweredOnVMGuestvCPUs = (Get-VM -Location $VMhost | Where-Object { $_.PowerState -eq "PoweredOn" } | Measure-Object NumCpu -Sum).Sum
    $ClusterVCPUs += $VMHostTotalPoweredOnVMGuestvCPUs
        
    $VMHostTotalPoweredOnVMGuestvRAM = (Get-VM -Location $VMhost | Where-Object { $_.PowerState -eq "PoweredOn" } | Measure-Object MemoryGB -Sum).Sum
    $ClusterVRAM += $VMHostTotalPoweredOnVMGuestvRAM
}

#First check
$Denied = $false
if ($ClusterVCPUs -gt ($ClusterPCPUs*3)) 
{
    Write-Host "The current allocation of virtual CPUs is already 3 times, or more, greater than the available physical CPU cores. VM build request DENIED!!!" -ForegroundColor Red
    $Denied = $true
}

if ($ClusterVRAM -gt $ClusterPRAM)
{
    Write-Host "The current allocation of RAM already exceeds the amount of physical RAM. VM build request DENIED!!!" -ForegroundColor Red
    $Denied = $true
}

#First check passed, getting number of servers that can fit
if (!($Denied))
{
    $AvailableVCPUs = ($ClusterPCPUs*3) - $ClusterVCPUs
    $ServerCountVCPU = [math]::Floor($AvailableVCPUs/4)

    $AvailableRAM = $ClusterPRAM - $ClusterVRAM
    $ServerCountRAM = [math]::Floor($AvailableRAM / 32)

    if ($Details)
    {
        Write-Host "This script will calculate the available space for VMs with 4vCPU's and 32 GB of RAM.`nNumber of VMs that can be added to the cluster is based on the metric that gives the fewest VMs." -ForegroundColor Yellow
        Write-Host "Available vCPUs = $AvailableVCPUs" -ForegroundColor Yellow
        Write-Host "This provides enough room for $ServerCountVCPU VMs." -ForegroundColor Yellow
        Write-Host "Available RAM in GB = $AvailableRAM" -ForegroundColor Yellow
        Write-Host "This provides enough room for $ServerCountRAM VMs." -ForegroundColor Yellow
    }
    else { Write-Host 'If you would like additional information, run the script with the "Details" parameter set to "$true".' -ForegroundColor Yellow }

    if ($ServerCountVCPU -le $ServerCountRAM) { Write-Host "This cluster is being limited by CPU.`nThere is enough room for $ServerCountVCPU VMs." -ForegroundColor Green }
    else { Write-Host "This cluster is being limited by RAM.`nThere is enough room for $ServerCountRAM VMs." -ForegroundColor Green }
}