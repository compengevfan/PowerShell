#This script is for updating the owner and purpose field of Fanatics vCenter servers based off a CSV file obtained from the Site reliability team.

[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] $DomainCredentials = $null
)
 
$ScriptPath = $PSScriptRoot
cd $ScriptPath
 
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
 
Check-PowerCLI
Connect-vCenter

$DataFromFile = Import-Csv .\FanaticsUpdateOwner-Purpose-Data.csv

foreach ($VM in $DataFromFile)
{
    $CurrentVM = Get-VM $($VM.VMName)
    if ($CurrentVM -eq $null)
    {
        $VM | Export-Csv .\FanaticsUpdateOwner-Purpose-NotFound.csv -Append
    }
    else
    {
        Get-VM $CurrentVM | Set-Annotation -CustomAttribute "Owner" -Value "$($VM.Owner)"
        Get-VM $CurrentVM | Set-Annotation -CustomAttribute "Purpose" -Value "$($VM.Purpose)"
    }

    Clear-Variable CurrentVM
}