[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] $CredFile = $null,
    [Parameter()] [bool] $SendEmail = $false
)

#requires -Version 3.0
$DupreeFunctionsMinVersion = "1.0.3"

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

#Email Variables
#emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = ""
$emailTo = ""
$emailServer = ""

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script Started..."

Connect-vCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting list of distributed switches..."
$Switches = Get-VDSwitch

$SwitchFails = @()
$PortGroupFails = @()

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking distributed switch configurations along with their portgroups..."
foreach($Switch in $Switches)
{
    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing switch $($Switch.Name)..."
    if ($Switch.Version -ne "6.5.0" `
        -or $Switch.NumUplinkPorts -ne 4 `
        -or $switch.LinkDiscoveryProtocol -ne "CDP" `
        -or $switch.LinkDiscoveryProtocolOperation -ne "Both" `
        -or $switch.Mtu -ne 9000)
    {
        Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$($Switch.Name) has a config problem."
        $SwitchFails += New-Object PSObject -Property @{
            SwitchName = $Switch.Name
            UplinkCount = $Switch.NumUplinkPorts
            LDP = $switch.LinkDiscoveryProtocol
            LDPO = $switch.LinkDiscoveryProtocolOperation
            Mtu = $switch.Mtu
        }
    }

    $PortGroups = Get-VDPortgroup -VDSwitch $Switch.Name
    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing portgroups on $($Switch.Name)..."
    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking for correct Kernel portgroups..."
    if ($PortGroups.Name -contains "VMkernel_SC" -and $PortGroups.Name -contains "VMkernel_vMotion1" -and $PortGroups.Name -contains "VMkernel_vMotion2") { Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Kernel portgroup names are correct."; $KernelPortGroups = $true }
    else { $KernelPortGroups = $false }
    foreach($PortGroup in $PortGroups)
    {
        Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing portgroup $($PortGroup.Name)..."
        switch($($PortGroup.Name))
        {
            "VMkernel_SC"
            {
                if ($PortGroup.)
            }
            "VMkernel_vMotion1"
            {

            }
            "VMkernel_vMotion2"
            {

            }
            default
            {

            }
        }
    }
}

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Script Completed Succesfully."