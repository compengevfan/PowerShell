[CmdletBinding()]
Param(
    [Parameter()] [string] $VMName
)

#requires -Version 7
#requires -Modules DupreeFunctions

$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

$LoggingSuccSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Succ" }
$LoggingInfoSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Info" }
$LoggingWarnSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Warn" }
$LoggingErrSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Err" }

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }

Import-DfPowerCLI

Invoke-DfLogging $LoggingInfoSplat -LogString "Script Started..."
cvc anthology.evorigin.com

$OperatingSystems = @(
    "Alma 9"
    "Windows 10"
    "Windows 11"
    "Windows 2016"
    "Windows 2019"
    "Windows 2022"
)
$OperatingSystemArray = $OperatingSystems | ForEach-Object { [PSCustomObject]@{ OperatingSystem = $_ } }
$OperatingSystemSelection = Invoke-DfMenu -Objects $OperatingSystemArray -MenuColumn OperatingSystem -SelectionText "Select CPU Count" -ClearScreen:$true

$vCpus = @(2,4,6,8)
$vCpuArray = $vCpus | ForEach-Object { [PSCustomObject]@{ vCPUs = $_ } }
$vCpuSelection = Invoke-DfMenu -Objects $vCpuArray -MenuColumn vCPUs -SelectionText "Select CPU Count" -ClearScreen:$true

$Ram = @(2,4,6,8)
$RamArray = $Ram | ForEach-Object { [PSCustomObject]@{ RAM = $_ } }
$RamSelection = Invoke-DfMenu -Objects $RamArray -MenuColumn RAM -SelectionText "Select RAM Amount" -ClearScreen:$true

$PortGroupArray = @("JAX-EvOrigin", "Test")
$PortGroupArray = $Ram | ForEach-Object { [PSCustomObject]@{ PortGroup = $_ } }
$PortGroupSelection = Invoke-DfMenu -Objects $PortGroupArray -MenuColumn PortGroup -SelectionText "Select a Portgroup" -ClearScreen:$true

$Datastores = @(
    "iSCSI-Storage1-NVMe"
    "iSCSI-Storage1-SSD"
    "iSCSI-Storage2-NVMe"
    "iSCSI-Storage2-SSD"
    "iSCSI-Storage3"
)
$DatastoreArray = $Datastores | ForEach-Object { [PSCustomObject]@{ Datastore = $_ } }
$DatastoreSelection = Invoke-DfMenu -Objects $DatastoreArray -MenuColumn Datastore -SelectionText "Select a Datastore" -ClearScreen:$true


Invoke-DfLogging $LoggingInfoSplat -LogString "Script Completed Succesfully."