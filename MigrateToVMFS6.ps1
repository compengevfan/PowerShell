[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [string] $Source,
    [Parameter(Mandatory=$true)] [string] $Destination
)
 
$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
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
 
if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}
 
Connect-vCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting the list of VMs to migrate..."
$VMsToMove = Get-Datastore $Source | Get-VM | Sort-Object Name

foreach ($VM in $VMsToMove)
{
    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Migrating VM $($VM.Name)..."

    $Task = Move-VM -VM $VM -Datastore $Destination -RunAsync
    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for task completion..."

    while($true)
    {
        if ($($Task.State) -eq "Success") { break }
        else { Start-Sleep 5 }
    }

    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Moving on..."
}

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying that all VMs were migrated..."
$VMsToMove = Get-Datastore $Source | Get-VM | Sort-Object Name

if ($VMsToMove.Count -gt 0) { Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Some VMs failed to move to the new Datastore!!! Please move manually or correct any issues and run the scrpt again!!!" }
else { Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Source datastore seems to be void of any VMs. Please verify and if confirmed, this datastore can be deleted." }