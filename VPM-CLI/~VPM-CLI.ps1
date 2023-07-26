[CmdletBinding()]
Param(
    [Parameter()] $vCenter,
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
 
if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}
 
Connect-DFvCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

if (!(Test-Path .\~Output)) { New-Item -Name "~Output" -ItemType Directory | Out-Null }

$Another = $true

while ($Another)
{
    cls
    $ObjectName = Read-Host "Please enter the name of the object to monitor"

    Write-Host "What type of object is it?`r`n`t1. VM`r`n`t2. Host`r`n`t3. DataStore"
    $ObjectType = Read-Host "Make a selection"

    switch ($ObjectType)
    {
        1
        {
            $ObjectToMonitor = Get-VM $ObjectName
            if ($ObjectToMonitor -eq $null -or $ObjectToMonitor -eq "") { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "VM with name $ObjectName does not exist." }
            else
            {
                Write-Host "What metric do you want to monitor?`r`n`t1. CPU`r`n`t2. Memory`r`n`t3. Storage"
                $Metric = Read-Host "Make a selection"

                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Executing 'MonitorObject' script in a new window..."
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Press '<ctrl> + C' in the new window to halt monitoring."
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "This window can be closed without impacting the monitoring window."
                Start-Process powershell -Argument "-File .\MonitorObject.ps1 -WhatToMonitor $ObjectName -ObjectType $ObjectType -Metric $Metric -vCenter $($global:defaultviserver.name) -CredFile $CredFile"
            }
        }
        2
        {
            $ObjectToMonitor = Get-VMHost $ObjectName
            if ($ObjectToMonitor -eq $null) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Host with name $ObjectName does not exist." }
            else
            {
                Write-Host "What metric do you want to monitor?`r`n`t1. CPU`r`n`t2. Memory`r`n`t3. Storage"
                $Metric = Read-Host "Make a selection"

                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Executing 'MonitorObject' script in a new window..."
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Press '<ctrl> + C' in the new window to halt monitoring."
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "This window can be closed without impacting the monitoring window."
                Start-Process powershell -Argument "-File .\MonitorObject.ps1 -WhatToMonitor $ObjectName -ObjectType $ObjectType -Metric $Metric -vCenter $($global:defaultviserver.name) -CredFile $CredFile"
            }
        }
        3
        {
            $ObjectToMonitor = Get-Datastore $ObjectName
            if ($ObjectToMonitor -eq $null) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Datastore with name $ObjectName does not exist." }
            else
            {
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Executing 'MonitorObject' script in a new window..."
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Press '<ctrl> + C' in the new window to halt monitoring."
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "This window can be closed without impacting the monitoring window."
                Start-Process powershell -Argument "-File .\MonitorObject.ps1 -WhatToMonitor $ObjectName -ObjectType $ObjectType -Metric 3 -vCenter $($global:defaultviserver.name) -CredFile $CredFile"
            }
        }
        default {}
    }

    Clear-Variable ObjectToMonitor

    $Check = Read-Host "Would you like to monitor another object (y/n)?"
    if ($Check -eq "n") { $Another = $false }
}