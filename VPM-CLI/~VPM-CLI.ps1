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
    cls
    $ObjectName = Read-Host "Please enter the name of the object to monitor"

    $ObjectType = Read-Host "What type of object is it (VM, Host, DataStore)?"

    switch ($ObjectType)
    {
        VM
        {
            $ObjectToMonitor = Get-VM $ObjectName
            if ($ObjectToMonitor -eq $null -or $ObjectToMonitor -eq "") { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "VM with name $ObjectName does not exist." }
            else
            {
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Executing 'MonitorObject' script in a new window..."
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Press '<ctrl> + C' in the new window to halt monitoring."
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "This window can be closed without impacting the monitoring window."
                Start-Process powershell -Argument "-File .\MonitorObject.ps1 -WhatToMonitor $ObjectName -ObjectType $ObjectType -vCenter $($global:defaultviserver.name)"
            }
        }
        Host
        {
            $ObjectToMonitor = Get-VMHost $ObjectName
            if ($ObjectToMonitor -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Host with name $ObjectName does not exist." }
            else
            {
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Executing 'MonitorObject' script in a new window..."
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Press '<ctrl> + C' in the new window to halt monitoring."
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "This window can be closed without impacting the monitoring window."
                Start-Process powershell -Argument "-File .\MonitorObject.ps1 -WhatToMonitor $ObjectName -ObjectType $ObjectType -vCenter $($global:defaultviserver.name)"
            }
        }
        DataStore
        {
            $ObjectToMonitor = Get-Datastore $ObjectName
            if ($ObjectToMonitor -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Datastore with name $ObjectName does not exist." }
            else
            {
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Executing 'MonitorObject' script in a new window..."
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Press '<ctrl> + C' in the new window to halt monitoring."
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "This window can be closed without impacting the monitoring window."
                Start-Process powershell -Argument "-File .\MonitorObject.ps1 -WhatToMonitor $ObjectName -ObjectType $ObjectType -vCenter $($global:defaultviserver.name)"
            }
        }
        default {}
    }

    Clear-Variable ObjectToMonitor

    $Check = Read-Host "Would you like to monitor another object (y/n)?"
    if ($Check -eq "n") { $Another = $false }
}