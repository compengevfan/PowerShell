[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] $CredFile = $null,
)

#requires -Version 3.0
$DupreeFunctionsMinVersion = "1.0.2"

$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
# if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
# if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }

#Check if DupreeFunctions is installed and verify version
if (!(Get-InstalledModule -Name DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion -ErrorAction SilentlyContinue))
{
    try 
    {
        if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Install-Module -Name DupreeFunctions -Scope CurrentUser -Force -ErrorAction Stop }
        else { Update-Module -Name DupreeFunctions -RequiredVersion $DupreeFunctionsMinVersion -Force -ErrorAction Stop }
    }
    catch { Write-Host "Failed to install 'DupreeFunctions' module from PSGallery!!! Error encountered is:`n`r`t$($Error[0])`n`rScript exiting!!!" -ForegroundColor Red ; exit }
}

if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
  
Import-PowerCLI
 
if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script Started..."

Connect-vCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use



Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Script Completed Succesfully."