[CmdletBinding()]
Param(
    [Parameter()] [string] $VMName
)

#requires -Version 7
#requires -Modules DupreeFunctions

$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }

Import-DfPowerCLI

Invoke-DfLogging $LoggingInfoSplat -LogString "Script Started..."
cvc anthology.evorigin.com



Invoke-DfLogging $LoggingInfoSplat -LogString "Script Completed Succesfully."