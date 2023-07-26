<#
What does the script do?
Returns the number of 4 core, 32GB of RAM VMs that can fit in a vCenter cluster based on N+1 (single host failure) cluster capacity.

Where/How does the script run?
The script can be run from anywhere that has access to connect to the vCenter server with the cluster to be checked.

What account do I run it with?
No specific account is needed. Your own login will work.

What is the syntax for executing?
ClusterCapacityCalculator.ps1 [-Details $true]

What does this script need to function properly?
1. "DupreeFunctions" PowerShell module in a path that is listed in the PSModulePath environment variable. I recommend "%ProgramFiles%\WindowsPowerShell\Modules".
2. PowerCLI must be installed.
#>

[CmdletBinding()]
Param(
    [Parameter()] [bool] $Details = $false
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
$ErrorActionPreference = "SilentlyContinue"
  
Function Check-PowerCLI
{
    Param(
    )
  
    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
        write-host ("Adding PowerCLI...")
        Get-Module -Name VMware* -ListAvailable | Import-Module -Global
        write-host ("Loaded PowerCLI.")
    }
}
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  
Check-PowerCLI
 
if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}
 
Connect-DFvCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

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