[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] $DomainCredentials = $null,
    [Parameter()] $SendEmail = $false
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
 
#$ErrorActionPreference = "SilentlyContinue"
#$WarningPreference = "SilentlyContinue"
 
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
 
Check-PowerCLI

#if there is no input file, present an explorer window for the user to select one.
if ($InputFile -eq "" -or $InputFile -eq $null) { cls; Write-Host "Please select a JSON file..."; $InputFile = Get-FileName }

#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $InputFile..."
try { $DataFromFile = ConvertFrom-JSON (Get-Content $InputFile -raw) }
catch [System.ArgumentException]
{ DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name." }

Write-Host "Blah"