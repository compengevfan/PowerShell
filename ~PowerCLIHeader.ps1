[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile
)

#requires -Version 7.2
#requires -Modules DupreeFunctions

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

$LoggingSuccSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Succ" }
$LoggingInfoSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Info" }
$LoggingWarnSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Warn" }
$LoggingErrSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Err" }

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
  
Import-DfPowerCLI

Invoke-DfLogging $LoggingInfoSplat -LogString "Script Started..."
Connect-DFvCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use


Invoke-DfLogging $LoggingInfoSplat -LogString "Script Completed Succesfully."