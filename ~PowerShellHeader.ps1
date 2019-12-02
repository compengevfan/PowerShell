[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] $CredFile = $null,
    [Parameter()] [bool] $SendEmail = $false
)

#requires -Version 3.0

$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
# if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
# if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }

#Check if DupreeFunctions is installed and verify version
if (!(Get-InstalledModule -Name DupreeFunctions -MinimumVersion 1.0.2 -ErrorAction SilentlyContinue))
{
    try { Install-Module -Name DupreeFunctions -Scope CurrentUser }
    catch { Write-Host "Failed to install 'DupreeFunctions' module from PSGallery!!! Error encountered is:`n`r$($Error[0])`n`rScript exiting!!!" ; exit }
}

if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
  
if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}

#Email Variables
#emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = ""
$emailTo = ""
$emailServer = ""
 
Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script Started..."



Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Script Completed Succesfully."