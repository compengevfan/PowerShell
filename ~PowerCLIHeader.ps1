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
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
  
Check-PowerCLI
 
if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}

##################
#Email Variables
##################
#emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "GoAnywhereMonitor@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"
 
Connect-vCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

#Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType 
<#
try
{
    Do-Something
    if (not expected) {Throw "Custom Error"}
}
catch 
{
    if ($Error[0].Exception.tostring() -like "*Custom Error") { "Custom Error Description" }
    else
    {
        $String = "Error encountered is:`n`r$($Error[0])`n`rScript executed on $($env:computername)."
        Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString $String
        if ($SendEmail) { Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "$ScriptName Encountered an Error" -Body $String }
    }
    exit
}
#>