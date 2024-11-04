[CmdletBinding()]
Param(
    [Parameter()] [string] $VMName
)

#requires -Version 7
#requires -Modules DupreeFunctions

$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

# $LoggingSuccSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Succ" }
# $LoggingInfoSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Info" }
# $LoggingWarnSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Warn" }
# $LoggingErrSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Err" }

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }

# Invoke-DfLogging $LoggingInfoSplat -LogString "Script Started..."

#Set VM Name to Uppercase
$VMName = $VMName.ToUpper()

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

$NetworkArray = @("JAX-EvOrigin", "Test")
$NetworkArray = $NetworkArray | ForEach-Object { [PSCustomObject]@{ Network = $_ } }
$NetworkSelection = Invoke-DfMenu -Objects $NetworkArray -MenuColumn Network -SelectionText "Select a Network" -ClearScreen:$true

$Datastores = @(
    "Storage1-NVMe"
    "Storage1-SSD"
    "Storage3-iSCSI"
)
$DatastoreArray = $Datastores | ForEach-Object { [PSCustomObject]@{ Datastore = $_ } }
$DatastoreSelection = Invoke-DfMenu -Objects $DatastoreArray -MenuColumn Datastore -SelectionText "Select a Datastore" -ClearScreen:$true

$vCenterFolders = @(
    "DC1/EvOrigin/DCs"
    "DC1/EvOrigin/Media Servers"
    "DC1/EvOrigin/Workers"
)
$vCenterFolderArray = $vCenterFolders | ForEach-Object { [PSCustomObject]@{ vCenterFolder = $_ } }
$vCenterFolderSelection = Invoke-DfMenu -Objects $vCenterFolderArray -MenuColumn vCenterFolder -SelectionText "Select a vCenter Folder" -ClearScreen:$true

$OUs = @(
    "evorigin.com/Virtual Servers"
    "evorigin.com/Virtual Workstations"
)
$OuArray = $OUs | ForEach-Object { [PSCustomObject]@{ Ou = $_ } }
$OuSelection = Invoke-DfMenu -Objects $OuArray -MenuColumn Ou -SelectionText "Select an OU" -ClearScreen:$true

$JsonTemplateContent = Get-Content $githome\vmbuildfiles\V2\~Template.json -Raw
$NewJsonContent = $JsonTemplateContent.Replace("[OperatingSystem]",$OperatingSystemSelection.OperatingSystem)
$NewJsonContent = $NewJsonContent.Replace("[vCPUs]",$vCpuSelection.vCPUs)
$NewJsonContent = $NewJsonContent.Replace("[RAM]",$RamSelection.RAM)
$NewJsonContent = $NewJsonContent.Replace("[Network]",$NetworkSelection.Network)
$NewJsonContent = $NewJsonContent.Replace("[Datastore]",$DatastoreSelection.Datastore)
$NewJsonContent = $NewJsonContent.Replace("[vCenterFolderPath]",$vCenterFolderSelection.vCenterFolder)
$NewJsonContent = $NewJsonContent.Replace("[OU]",$OuSelection.Ou)
$NewJsonContent | Out-File "$githome\vmbuildfiles\V2\$VMName.json" -Force

# Invoke-DfLogging $LoggingInfoSplat -LogString "Script Completed Succesfully."