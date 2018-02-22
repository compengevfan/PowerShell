[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter,
    [Parameter()] [string] $InputFile
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath

. .\Functions\function_Check-PowerCLI.ps1
. .\Functions\function_Connect-vCenter.ps1
. .\Functions\function_Get-FileName.ps1
. .\Functions\function_Wait-Shutdown.ps1

Check-PowerCLI

##################
#System/Global Variables
##################
$ErrorActionPreference = "SilentlyContinue"
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

Connect-vCenter -vCenter $vCenter

#if there is no input file, present an explorer window for the user to select one.
if ($InputFile -eq "" -or $InputFile -eq $null) { cls; Write-Host "Please select an input file..."; $InputFile = Get-FileName }

#Grab the list of servers to upgrade
$VMsToUpdate = Get-Content $InputFile

#Upgrade VMs
$VMCount = $VMsToUpdate.Count
i = 1
foreach ($VMToUpdate in $VMsToUpdate)
{
    Write-Progress -Activity "Processing VMs" -status "Checking Server $i of $VMCount" -percentComplete ($i / $VMCount*100)

    $Blah = Get-VM $VMToUpdate
    $Blah | Update-Tools
    Wait-Tools -VM $Blah -TimeoutSeconds 600

    Shutdown-VMGuest $Blah -Confirm:$false
    Set-VM $Blah -Version v11 -Confirm:$false
    Start-VM $Blah
    Wait-Tools -VM $Blah -TimeoutSeconds 600
    Restart-VMGuest $Blah

    i++
}