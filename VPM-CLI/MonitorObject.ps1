[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)] [string] $WhatToMonitor,
    [Parameter(Mandatory=$True)] [string] $ObjectType,
    [Parameter(Mandatory=$True)] $vCenter
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
Connect-vCenter $vCenter

$host.ui.RawUI.WindowTitle = "Monitoring $WhatToMonitor"

while ($True)
{
    cls

    switch ($ObjectType)
    {
        VM
        {
            $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat `
             cpu.usage.average `
            ,cpu.ready.summation `
            ,cpu.costop.summation `
            ,mem.vmmemctl.average `
            ,datastore.totalReadLatency.average `
            ,datastore.totalWriteLatency.average `
            ,datastore.read.average `
            ,datastore.write.average | Sort-Object MetricID,Instance
        }
        Host
        {
            $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat `
             cpu.usage.average `
            ,cpu.ready.summation `
            ,mem.vmmemctl.average `
            ,datastore.totalReadLatency.average `
            ,datastore.totalWriteLatency.average `
            ,datastore.read.average `
            ,datastore.write.average | Sort-Object MetricID,Instance
        }
        DataStore
        {
            $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat `
             datastore.numberReadAveraged.average `
            ,datastore.numberWriteAveraged.average | Sort-Object MetricID,Instance
        }
    }
    
    $Data | FT -Auto
    sleep 20
}
