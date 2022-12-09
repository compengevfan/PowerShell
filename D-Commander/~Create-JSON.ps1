[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter
)
 
$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
 
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
cvi $vCenter

while ($true)
{
    $TargetClusterStr = Read-Host "Please enter the name of the Cluster"
    $TargetCluster = Get-Cluster $TargetClusterStr
    if ($TargetCluster -eq $null) { Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Cluster named '$TargetClusterStr' does not exist. Please try again..." }
    else { break }
}

$TargetDataCenter = $TargetCluster | Get-Datacenter

$NameOfVM = Read-Host "VM Name"
$Owner = Read-Host "VM Owner (this can be an individual or a group)"
$Purpose = Read-Host "VM Purpose"
$FolderPath = Read-Host "Folder Path (default is '[DataCenter]/Discovered virtual machine')"

if ($FolderPath -eq "") { $FolderPath = "$TargetDataCenter/Discovered virtual machine" }

Get-Cluster ClusterInQuestion | get-VMHost | get-datastore | get-datastorecluster