[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter,
    [Parameter()] $null = $CredFile
)

#requires -Version 3.0
$DupreeFunctionsMinVersion = "1.0.3"

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
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
  
Import-DfPowerCLI
 
if ($null -ne $CredFile)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script Started..."

Connect-DFvCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting list of distributed switches..."
$Switches = Get-VDSwitch

$SwitchFails = @()
$PortGroupFails = @()

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking distributed switch configurations along with their portgroups..."
foreach($Switch in $Switches)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing switch $($Switch.Name)..."
    $PortGroups = Get-VDPortgroup -VDSwitch $Switch.Name
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking for correct Kernel portgroups..."
    if ($PortGroups.Name -contains "VMkernel_SC" -and $PortGroups.Name -contains "VMkernel_vMotion1" -and $PortGroups.Name -contains "VMkernel_vMotion2") { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Kernel portgroup names are correct."; $KernelPortGroups = $true }
    else { $KernelPortGroups = $false }
    if ($Switch.Version -ne "6.5.0" `
        -or $Switch.NumUplinkPorts -ne 4 `
        -or $switch.LinkDiscoveryProtocol -ne "CDP" `
        -or $switch.LinkDiscoveryProtocolOperation -ne "Both" `
        -or $switch.Mtu -ne 9000 `
        -or !($KernelPortGroups))
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$($Switch.Name) has a config problem."
        $SwitchFails += New-Object PSObject -Property @{
            SwitchName = $Switch.Name
            UplinkCount = $Switch.NumUplinkPorts
            LDP = $switch.LinkDiscoveryProtocol
            LDPO = $switch.LinkDiscoveryProtocolOperation
            Mtu = $switch.Mtu
            KernelPorts = $KernelPortGroups
        }
    }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing portgroups on $($Switch.Name)..."
    foreach($PortGroup in $PortGroups)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing portgroup $($PortGroup.Name)..."
        $PortGroupCheck = $PortGroup | Get-VDUplinkTeamingPolicy
        switch($($PortGroup.Name))
        {
            "VMkernel_SC"
            {
                if ($PortGroupCheck.LoadBalancingPolicy -ne "LoadBalanceLoadBased" `
                    -or $PortGroupCheck.FailoverDetectionPolicy -ne "BeaconProbing" `
                    -or $PortGroupCheck.EnableFailback -ne $false `
                    -or $PortGroupCheck.ActiveUplinkPort.Count -ne 4)
                {
                    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$($PortGroup.Name) has a config problem..."
                    $PortGroupFails += New-Object PSObject -Property @{
                        SwitchName = $Switch.Name
                        PortGroupName = $PortGroup.Name
                        LBPolicy = $PortGroupCheck.LoadBalancingPolicy
                        FDPolicy = $PortGroupCheck.FailoverDetectionPolicy
                        Failback = $PortGroupCheck.EnableFailback
                        ActiveUplinkCount = $PortGroupCheck.ActiveUplinkPort.Count
                    }
                }
            }
            "VMkernel_vMotion1"
            {
                if ($PortGroupCheck.LoadBalancingPolicy -ne "ExplicitFailover" `
                    -or $PortGroupCheck.FailoverDetectionPolicy -ne "BeaconProbing" `
                    -or $PortGroupCheck.EnableFailback -ne $true `
                    -or $PortGroupCheck.ActiveUplinkPort  -ne "dvUplink2" `
                    -or $PortGroupCheck.StandbyUplinkPort.Count -ne 3)
                {
                    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$($PortGroup.Name) has a config problem..."
                    $PortGroupFails += New-Object PSObject -Property @{
                        SwitchName = $Switch.Name
                        PortGroupName = $PortGroup.Name
                        LBPolicy = $PortGroupCheck.LoadBalancingPolicy
                        FDPolicy = $PortGroupCheck.FailoverDetectionPolicy
                        Failback = $PortGroupCheck.EnableFailback
                        ActiveUplinkCount = $PortGroupCheck.ActiveUplinkPort
                        StandbyUplinkCount = $PortGroupCheck.StandbyUplinkPort.Count
                    }
                }
            }
            "VMkernel_vMotion2"
            {
                if ($PortGroupCheck.LoadBalancingPolicy -ne "ExplicitFailover" `
                    -or $PortGroupCheck.FailoverDetectionPolicy -ne "BeaconProbing" `
                    -or $PortGroupCheck.EnableFailback -ne $true `
                    -or $PortGroupCheck.ActiveUplinkPort  -ne "dvUplink3" `
                    -or $PortGroupCheck.StandbyUplinkPort.Count -ne 3)
                {
                    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$($PortGroup.Name) has a config problem..."
                    $PortGroupFails += New-Object PSObject -Property @{
                        SwitchName = $Switch.Name
                        PortGroupName = $PortGroup.Name
                        LBPolicy = $PortGroupCheck.LoadBalancingPolicy
                        FDPolicy = $PortGroupCheck.FailoverDetectionPolicy
                        Failback = $PortGroupCheck.EnableFailback
                        ActiveUplinkCount = $PortGroupCheck.ActiveUplinkPort
                        StandbyUplinkCount = $PortGroupCheck.StandbyUplinkPort.Count
                    }
                }
            }
            default
            {
                if ($PortGroupCheck.LoadBalancingPolicy -ne "LoadBalanceLoadBased" `
                    -or $PortGroupCheck.FailoverDetectionPolicy -ne "BeaconProbing" `
                    -or $PortGroupCheck.EnableFailback -ne $false `
                    -or $PortGroupCheck.ActiveUplinkPort.Count -ne 4)
                {
                    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$($PortGroup.Name) has a config problem..."
                    $PortGroupFails += New-Object PSObject -Property @{
                        SwitchName = $Switch.Name
                        PortGroupName = $PortGroup.Name
                        LBPolicy = $PortGroupCheck.LoadBalancingPolicy
                        FDPolicy = $PortGroupCheck.FailoverDetectionPolicy
                        Failback = $PortGroupCheck.EnableFailback
                        ActiveUplinkCount = $PortGroupCheck.ActiveUplinkPort.Count
                    }
                }
            }
        }
    }
}



if ($SwitchFails.Count -gt 0 -or $PortGroupFails -gt 0)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing improperly configured switches and building the email body..."
    $OutputString = "The following switches or portgroups are misconfigured in vCenter $vCenter. The incorrect settings are listed with the appropriate setting."

    foreach($SwitchFail in $SwitchFails)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding $($SwitchFail.SwitchName) to the email..."
        $OutputString += "Switch: $($SwitchFail.SwitchName)`r`n"

        if ($SwitchFail.UplinkCount -ne 4) { $OutputString += "UpLink Count: $($SwitchFail.UplinkCount)`r`n" }
        if ($SwitchFail.LDP -ne "CDP") { $OutputString += "LinkDiscoveryProtocol: $($SwitchFail.LDP)`r`n" }
        if ($SwitchFail.LDPO -ne "Both") { $OutputString += "LinkDiscoveryProtocolOperation: $($SwitchFail.LDPO)`r`n" }
        if ($SwitchFail.Mtu -ne 9000) { $OutputString += "MTU: $($SwitchFail.Mtu)`r`n" }
        if ($SwitchFail.KernelPorts -eq $false) { $OutputString += "Kernel portgroups are not named correctly." }
    }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Logging config problems...`r`n`r`n$OutputString"
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Script Completed Succesfully."