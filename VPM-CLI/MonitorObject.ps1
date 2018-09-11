[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)] [string] $WhatToMonitor,
    [Parameter(Mandatory=$True)] [int] $ObjectType,
    [Parameter()] [int] $Metric,
    [Parameter(Mandatory=$True)] $vCenter,
    [Parameter()] $CredFile
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

New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))

Connect-vCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

switch ($Metric)
{
    1 { $host.ui.RawUI.WindowTitle = "Monitoring $WhatToMonitor CPU" }
    2 { $host.ui.RawUI.WindowTitle = "Monitoring $WhatToMonitor Memory" }
    3 { $host.ui.RawUI.WindowTitle = "Monitoring $WhatToMonitor Storage" }
    default {  }
}

while ($True)
{
    cls

    switch ($ObjectType)
    {
        1
        { #VM
            switch ($Metric)
            {
                1 { $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat cpu.usage.average,cpu.ready.summation,cpu.costop.summation | Sort-Object MetricID,Instance }
                2 { $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat mem.vmmemctl.average | Sort-Object MetricID,Instance }
                3 { $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat datastore.totalReadLatency.average,datastore.totalWriteLatency.average,datastore.read.average,datastore.write.average | Sort-Object MetricID,Instance }
            }
        }
        2
        { #Host
            switch ($Metric)
            {
                1 { $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat cpu.usage.average,cpu.ready.summation | Sort-Object MetricID,Instance }
                2 { $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat mem.vmmemctl.average | Sort-Object MetricID,Instance }
                3 { $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat datastore.totalReadLatency.average,datastore.totalWriteLatency.average,datastore.read.average,datastore.write.average | Sort-Object MetricID,Instance }
            }
        }
        3
        { #DataStore
            $Data = Get-Stat $WhatToMonitor -Realtime -MaxSamples 1 -Stat datastore.numberReadAveraged.average,datastore.numberWriteAveraged.average | Sort-Object MetricID,Instance
        }
    }
    
    $Data | FT -Auto
    sleep 20
}
