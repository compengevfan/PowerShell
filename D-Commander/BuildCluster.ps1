[CmdletBinding()]
Param(
    [Parameter()] [string] $VMNode1,
    [Parameter()] [string] $VMNode2,
    [Parameter()] [string] $ClusterConfig,
    [Parameter()] $SendEmail = $true
)

#$ErrorActionPreference = "SilentlyContinue"

#Import functions
. .\Functions\function_Get-FileName
. .\Functions\function_DoLogging
. .\Functions\function_Check-PowerCLI.ps1

if ($VMNode1 -eq "" -or $VMNode1 -eq $null) { cls; Write-Host "Please select a JSON file for node 1..."; $VMNode1 = Get-FileName }
if ($VMNode2 -eq "" -or $VMNode2 -eq $null) { cls; Write-Host "Please select a JSON file for node 2..."; $VMNode2 = Get-FileName }
if ($ClusterConfig -eq "" -or $ClusterConfig -eq $null) { cls; Write-Host "Please select a JSON file for the cluster config..."; $ClusterConfig = Get-FileName }

$InputFileName = Get-Item $ClusterConfig | % {$_.BaseName}
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "BuildCluster@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

Check-PowerCLI

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
if (!(Test-Path .\~Processed-JSON-Files)) { New-Item -Name "~Processed-JSON-Files" -ItemType Directory | Out-Null }

cls
#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -LogType Info -LogString "Importing JSON Data File: $VMNode1..."
$DataFromFile = ConvertFrom-JSON (Get-Content $VMNode1 -raw)
if ($DataFromFile -eq $null) { DoLogging -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -LogType Info -LogString "Importing JSON Data File: $VMNode2..."
$DataFromFile2 = ConvertFrom-JSON (Get-Content $VMNode2 -raw)
if ($DataFromFile2 -eq $null) { DoLogging -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -LogType Info -LogString "Importing JSON Data File: $ClusterConfig..."
$DataFromFile3 = ConvertFrom-JSON (Get-Content $ClusterConfig -raw)
if ($DataFromFile3 -eq $null) { DoLogging -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Get the array of disks from the json file and verify that it's not too many...
$DisksToAdd = $ClusterConfig.AdditionalDisks
if ($DisksToAdd.Count -gt 15) { DoLogging -LogType Err -LogString "This script doesn't support more than 15 data disks, including the G Drive. Please build VM with Cloud-o-MITE and add disks manually or reduce the number of data disks."; exit }

#If not connected to a vCenter, connect.
$ConnectedvCenter = $global:DefaultVIServers
if ($ConnectedvCenter.Count -eq 0)
{
    do
    {
        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) {  DoLogging -LogType Info -LogString "Attempting to connect to vCenter server $($DataFromFile.VMInfo.vCenter)" }
        
        Connect-VIServer $($DataFromFile.VMInfo.vCenter) | Out-Null
        $ConnectedvCenter = $global:DefaultVIServers

        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null){ DoLogging -LogType Warn -LogString "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
    } while ($ConnectedvCenter.Count -eq 0)
}

if ($DomainCredentials -eq $null)
{
    while($true)
    {
        DoLogging -LogType Warn -LogString "Obtaining Domain Credentials. Note: Username MUST be in 'user principle name' format. For example: me@domain.com"
        $DomainCredentials = Get-Credential -Message "READ ME!!! Please provide a username and password for the $($DataFromFile.GuestInfo.Domain) domain. Username MUST be in 'user principle name' format. For example: me@domain.com"
        DoLogging -LogType Info -LogString "Testing domain credentials..."
        #Verify Domain Credentials
        $username = $DomainCredentials.username
        $password = $DomainCredentials.GetNetworkCredential().password

        # Get current domain using logged-on user's credentials
        $CurrentDomain = "LDAP://" + $($DataFromFile.GuestInfo.Domain)
        $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

        if ($domain.name -eq $null) { DoLogging -LogType Warn -LogString "Domain Credentials Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
        else { DoLogging -LogType Succ -LogString "Credential test was successful..."; break }
    }
}

.\Cloud-O-MITE.ps1 -InputFile $VMNode1 -DomainCredentials $DomainCredentials
.\Cloud-O-MITE.ps1 -InputFile $VMNode2 -DomainCredentials $DomainCredentials

#Delete G Drive from Node 1 and Node 2
DoLogging -LogType Info -LogString "Removing G Drive from Node 1..."
Get-HardDisk -VM $($DataFromFile.VMInfo.VMName) | Where-Object { $_.Name -eq "Hard Disk 3" } | Remove-HardDisk -DeletePermanently -Confirm:$false | Out-Null
DoLogging -LogType Info -LogString "Removing G Drive from Node 2..."
Get-HardDisk -VM $($DataFromFile2.VMInfo.VMName) | Where-Object { $_.Name -eq "Hard Disk 3" } | Remove-HardDisk -DeletePermanently -Confirm:$false | Out-Null

#Shutdown the nodes 
DoLogging -LogType Info -LogString "Shutting down Node 1..."
Shutdown-VMGuest $($DataFromFile.VMInfo.VMName) -Confirm:$false | Out-Null
Clear-Variable PowerState
while ($PowerState -ne "PoweredOff")
{
    Start-Sleep 5
    $PowerState = (Get-VM $($DataFromFile.VMInfo.VMName)).PowerState
}

DoLogging -LogType Info -LogString "Shutting down Node 2..."
Shutdown-VMGuest $($DataFromFile2.VMInfo.VMName) -Confirm:$false | Out-Null
Clear-Variable PowerState
while ($PowerState -ne "PoweredOff")
{
    Start-Sleep 5
    $PowerState = (Get-VM $($DataFromFile2.VMInfo.VMName)).PowerState
}

#Creating a new G Drive on Node 1 and moving to a new SCSI controller with Physical Bus Sharing. 
DoLogging -LogType Info -LogString "Creating a new G Drive on Node 1 and moving to a new SCSI controller with Physical Bus Sharing..."
$G_Drive1 = Get-VM $($DataFromFile.VMInfo.VMName) | New-HardDisk -CapacityGB 10 -StorageFormat EagerZeroedThick -Datastore $($DataFromFile3.ClusterInfo.DedicatedDS)
$NewController1 = New-ScsiController -HardDisk $G_Drive1 -BusSharingMode Physical -Type ParaVirtual -Confirm:$false

#Change the SCSI ID of the moved disk
DoLogging -LogType Info -LogString "Changing the SCSI ID of the G drive from 2 to 0..."
$FirstNode = Get-VM $($DataFromFile.VMInfo.VMName)
$G_Drive1 = Get-VM $($DataFromFile.VMInfo.VMName) | Get-HardDisk | Where-Object { $_.Name -eq "Hard Disk 3" }
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = "edit"
$spec.deviceChange[0].device = $G_Drive1.ExtensionData
$spec.deviceChange[0].device.unitNumber = 0
$FirstNode.ExtensionData.ReconfigVM($spec)

#Add G Drive from Node 1 to Node 2
DoLogging -LogType Info -LogString "Adding G drive from Node 1 to Node 2 and moving to a new SCSI controller with Physical Bus Sharing..."
$SecondNode = Get-VM $($DataFromFile2.VMInfo.VMName)
$G_Drive2 = New-HardDisk -VM $SecondNode -DiskPath $($G_Drive1.Filename)
$NewController2 = New-ScsiController -HardDisk $G_Drive2 -BusSharingMode Physical -Type ParaVirtual -Confirm:$false

#Change the SCSI ID of the moved disk
DoLogging -LogType Info -LogString "Changing the SCSI ID of the G drive from 2 to 0..."
$SecondNode = Get-VM $($DataFromFile2.VMInfo.VMName)
$G_Drive2 = Get-VM $($DataFromFile2.VMInfo.VMName) | Get-HardDisk | Where-Object { $_.Name -eq "Hard Disk 3" }
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = "edit"
$spec.deviceChange[0].device = $G_Drive2.ExtensionData
$spec.deviceChange[0].device.unitNumber = 0
$SecondNode.ExtensionData.ReconfigVM($spec)

$DiskNumber = 2
$VolumeNumber = 4

#Adding additional disks listed in cluster config file
foreach()
{
    New-HardDisk -VM $FirstNode -Controller $NewController -CapacityGB 10 -StorageFormat Thick
}

