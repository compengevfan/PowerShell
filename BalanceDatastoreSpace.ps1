﻿<#
What does the script do?
Performs storage vMotions to balance out VMs across the datastores in a datastore cluster. Example use case is a new datastore/volume is created and added to a datastore cluster. 

Where/How does the script run?
The script can be run from anywhere that has access to connect to the vCenter server with the datastore cluster to be balanced.

What account do I run it with?
No specific account is needed. Your own login will work.

What is the syntax for executing?
BalanceDatastoreSpace.ps1

What does this script need to function properly?
1. "DupreeFunctions" PowerShell module in a path that is listed in the PSModulePath environment variable. I recommend "%ProgramFiles%\WindowsPowerShell\Modules".
2. PowerCLI must be installed.
#>

[CmdletBinding()]
Param(
)
 
$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ErrorActionPreference = "SilentlyContinue"
  
Function Add-PowerCLI
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
  
Add-PowerCLI
 
if ($null -ne $CredFile)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}
 
Connect-DFvCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

$DatastoreCluster = Read-Host -Prompt ("Please enter the name of the datastore cluster to be balanced")

#Retrieve datastores from cluster
$DatastoresToBalance = Get-DatastoreCluster $DatastoreCluster | Get-Datastore | Sort-Object FreeSpaceGB

#Find datastore with least and most free space
$DSleastFree = $DatastoresToBalance | Select-Object -First 1
$DSmostFree = $DatastoresToBalance | Select-Object -Last 1

#Figure out if balancing needs to occur
$Space1 = $DSmostFree.FreeSpaceGB
$Space2 = $DSleastFree.FreeSpaceGB
$Diff = $Space1 - $Space2
if ($Diff -gt 100 -and $DatastoresToBalance.Count -gt 1) { $RunAgain = $true }
else
{
    $RunAgain = $false
    Write-Host ("Exiting script. Cluster is either balanced or only has 1 datastore")
}

while ($RunAgain)
{
    #Get list of VM on DS with least space and pick a random VM
    $SourceVMs = Get-VM -Datastore $DSleastFree.Name | Sort-Object Name
    $SourceVMCount = $SourceVMs.Count
    $RandomNumber = Get-Random -Maximum $SourceVMCount

    $VMtoMove = $SourceVMs[$RandomNumber]

    Write-Host ("Moving $($VMtoMove.Name) from $($DSleastFree.Name) to $($DSmostFree.Name).")
    Move-VM -VM $VMtoMove -Datastore $DSmostFree.Name -Confirm:$false | Out-Null

    Start-Sleep 5

    #Retrieve datastores from cluster
    $DatastoresToBalance = Get-DatastoreCluster $DatastoreCluster | Get-Datastore | Sort-Object FreeSpaceGB

    #Find datastore with least and most free space
    $DSleastFree = $DatastoresToBalance | Select-Object -First 1
    $DSmostFree = $DatastoresToBalance | Select-Object -Last 1

    #Figure out if balancing needs to occur
    $Space1 = $DSmostFree.FreeSpaceGB
    $Space2 = $DSleastFree.FreeSpaceGB
    $Diff = $Space1 - $Space2
    if ($Diff -lt 100)
    {
        $RunAgain = $false
        Write-Host ("Script complete. Cluster is now balanced.")
    }
}