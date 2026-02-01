[CmdletBinding()]
Param(
)
 
$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
$ErrorActionPreference = "SilentlyContinue"
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }

$Cluster = Read-Host -Prompt ("Please enter the name of the cluster to be balanced")
#Retrieve hosts from cluster
$HostsToBalance = Get-Cluster $Cluster | Get-VMHost | Where-Object {$_.ConnectionState -eq "Connected"} | Sort-Object MemoryUsageGB
if ($null -ne $HostsToBalance) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Balancing Cluster $Cluster..." }
else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "$Cluster does not exist!!! Script Exiting!!!"; exit }

#Find datastore with least and most free space
$HostLeastUsed = $HostsToBalance | Select-Object -First 1
$HostMostUsed = $HostsToBalance | Select-Object -Last 1

#Figure out if balancing needs to occur
$Space1 = $HostMostUsed.MemoryUsageGB
$Space2 = $HostLeastUsed.MemoryUsageGB
$Diff = $Space1 - $Space2
if ($Diff -gt 8 -and $HostsToBalance.Count -gt 1) { $RunAgain = $true }
else
{
    $RunAgain = $false
    Write-Host ("Exiting script. Cluster is either balanced or only has 1 host")
}

while ($RunAgain)
{
    #Get list of VM on DS with least space and pick a random VM
    $SourceVMs = Get-VMHost $HostMostUsed | Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" } | Sort-Object Name
    $SourceVMCount = $SourceVMs.Count
    $RandomNumber = Get-Random -Maximum $SourceVMCount

    $VMtoMove = $SourceVMs[$RandomNumber]

    Move-VM -VM $VMtoMove -Destination $HostLeastUsed.Name -Confirm:$false | Out-Null
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Migrated $($VMtoMove.Name) from $($HostMostUsed.Name) to $($HostLeastUsed.Name)."

    $HostsToBalance = Get-Cluster $Cluster | Get-VMHost | Where-Object {$_.ConnectionState -eq "Connected"} | Sort-Object MemoryUsageGB

    $HostLeastUsed = $HostsToBalance | Select-Object -First 1
    $HostMostUsed = $HostsToBalance | Select-Object -Last 1

    #Figure out if balancing needs to occur
    $Space1 = $HostMostUsed.MemoryUsageGB
    $Space2 = $HostLeastUsed.MemoryUsageGB
    $Diff = $Space1 - $Space2
    if ($Diff -lt 8)
    {
        $RunAgain = $false
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script complete. Cluster is now balanced."
        #Write-Host ("Script complete. Cluster is now balanced.")
    }
}