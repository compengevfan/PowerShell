[CmdletBinding()]
Param(
)
 
$ScriptPath = $PSScriptRoot
cd $ScriptPath
 
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
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
Connect-vCenter

$Another = $true

while ($Another)
{
    $ObjectName = Read-Host "Please enter the name of the object to monitor"

    $ObjectType = Read-Host "What type of object is it (VM, Host, DataStore)?"

    switch ($ObjectType)
    {
        VM
        {
            
        }
        Host {}
        DataStore {}
        default {}
    }

    $Check = Read-Host "Would you like to monitor another object (y/n)?"
    if ($Check = "n") { $Another = $false }
}

#Get-Stat Solitude -Realtime -MaxSamples 1 -Stat cpu.usage.average,cpu.ready.summation,mem.vmmemctl.average,virtualDisk.totalReadLatency.average,virtualDisk.totalWriteLatency.average | Sort-Object MetricID,Instance | FT -Auto