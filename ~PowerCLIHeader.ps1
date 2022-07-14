[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] [bool] $SendEmail = $false
)

<<<<<<< Updated upstream
#Requires -Version 7.2
$DupreeFunctionsMinVersion = "1.0.2"
=======
#requires -Version 7.2
#requires -Modules DupreeFunctions
>>>>>>> Stashed changes

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"

if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
  
Import-PowerCLI
 
if ($null -ne $CredFile)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}

#Email Variables
#emailTo is a comma separated list of strings eg. "email1","email2"
# $emailFrom = ""
# $emailTo = ""
# $emailServer = ""

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script Started..."

Connect-vCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use



Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Script Completed Succesfully."