[CmdletBinding()]
Param(
    [Parameter()] [string] $VMNode1,
    [Parameter()] [string] $VMNode2,
    [Parameter()] [string] $ClusterConfig,
    [Parameter()] $SendEmail = $true
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

##############################################################################################################################

if ($VMNode1 -eq "" -or $VMNode1 -eq $null) { cls; Write-Host "Please select a JSON file for node 1..."; $VMNode1 = Get-FileName }
if ($VMNode2 -eq "" -or $VMNode2 -eq $null) { cls; Write-Host "Please select a JSON file for node 2..."; $VMNode2 = Get-FileName }
if ($ClusterConfig -eq "" -or $ClusterConfig -eq $null) { cls; Write-Host "Please select a JSON file for the cluster config..."; $ClusterConfig = Get-FileName }

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "BuildCluster@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
if (!(Test-Path .\~Processed-JSON-Files)) { New-Item -Name "~Processed-JSON-Files" -ItemType Directory | Out-Null }

cls
#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $VMNode1..."
$DataFromFile = ConvertFrom-JSON (Get-Content $VMNode1 -raw)
if ($DataFromFile -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $VMNode2..."
$DataFromFile2 = ConvertFrom-JSON (Get-Content $VMNode2 -raw)
if ($DataFromFile2 -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $ClusterConfig..."
$DataFromFile3 = ConvertFrom-JSON (Get-Content $ClusterConfig -raw)
if ($DataFromFile3 -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Get the array of disks from the json file and verify that it's not too many...
$DisksToAdd = $DataFromFile3.AdditionalDisks
if ($DisksToAdd.Count -gt 12) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "This script doesn't support more than 15 data disks, including the G, M and Q Drives. Please build VM with Cloud-o-MITE and add disks manually or reduce the number of data disks."; exit }

#If not connected to a vCenter, connect.
Connect-vCenter $($DataFromFile.VMInfo.vCenter)

if ($DomainCredentials -eq $null)
{
    while($true)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Obtaining Domain Credentials. Note: Username MUST be in 'user principle name' format. For example: me@domain.com"
        $DomainCredentials = Get-Credential -Message "READ ME!!! Please provide a username and password for the $($DataFromFile.GuestInfo.Domain) domain. Username MUST be in 'user principle name' format. For example: me@domain.com"
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Testing domain credentials..."
        #Verify Domain Credentials
        $username = $DomainCredentials.username
        $password = $DomainCredentials.GetNetworkCredential().password

        # Get current domain using logged-on user's credentials
        $CurrentDomain = "LDAP://" + $($DataFromFile.GuestInfo.Domain)
        $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

        if ($domain.name -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Domain Credentials Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
        else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Credential test was successful..."; break }
    }
}

.\Cloud-O-MITE.ps1 -InputFile $VMNode1 -DomainCredentials $DomainCredentials
.\Cloud-O-MITE.ps1 -InputFile $VMNode2 -DomainCredentials $DomainCredentials

#Delete G Drive from Node 1 and Node 2
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Removing G Drive from Node 1..."
Get-HardDisk -VM $($DataFromFile.VMInfo.VMName) | Where-Object { $_.Name -eq "Hard Disk 3" } | Remove-HardDisk -DeletePermanently -Confirm:$false | Out-Null
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Removing G Drive from Node 2..."
Get-HardDisk -VM $($DataFromFile2.VMInfo.VMName) | Where-Object { $_.Name -eq "Hard Disk 3" } | Remove-HardDisk -DeletePermanently -Confirm:$false | Out-Null

#Shutdown the nodes 
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down Node 1..."
Shutdown-VMGuest $($DataFromFile.VMInfo.VMName) -Confirm:$false | Out-Null
if ($Powerstate -ne $null) { Clear-Variable PowerState }
while ($PowerState -ne "PoweredOff")
{
    Start-Sleep 5
    $PowerState = (Get-VM $($DataFromFile.VMInfo.VMName)).PowerState
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down Node 2..."
Shutdown-VMGuest $($DataFromFile2.VMInfo.VMName) -Confirm:$false | Out-Null
if ($Powerstate -ne $null) { Clear-Variable PowerState }
while ($PowerState -ne "PoweredOff")
{
    Start-Sleep 5
    $PowerState = (Get-VM $($DataFromFile2.VMInfo.VMName)).PowerState
}

#Creating a new G Drive on Node 1 and moving to a new SCSI controller with Physical Bus Sharing. 
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating a new G Drive on Node 1 and moving to a new SCSI controller with Physical Bus Sharing..."
$G_Drive1 = Get-VM $($DataFromFile.VMInfo.VMName) | New-HardDisk -CapacityGB 10 -StorageFormat EagerZeroedThick -Datastore $($DataFromFile3.ClusterInfo.DedicatedDS)
$NewController1 = New-ScsiController -HardDisk $G_Drive1 -BusSharingMode Physical -Type ParaVirtual -Confirm:$false

#Change the SCSI ID of the moved disk
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Changing the SCSI ID of the G drive from 2 to 0..."
$FirstNode = Get-VM $($DataFromFile.VMInfo.VMName)
$G_Drive1 = Get-VM $($DataFromFile.VMInfo.VMName) | Get-HardDisk | Where-Object { $_.Name -eq "Hard Disk 3" }
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = "edit"
$spec.deviceChange[0].device = $G_Drive1.ExtensionData
$spec.deviceChange[0].device.unitNumber = 0
$FirstNode.ExtensionData.ReconfigVM($spec)

#Add G Drive from Node 1 to Node 2
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding G drive from Node 1 to Node 2 and moving to a new SCSI controller with Physical Bus Sharing..."
$SecondNode = Get-VM $($DataFromFile2.VMInfo.VMName)
$G_Drive2 = New-HardDisk -VM $SecondNode -DiskPath $($G_Drive1.Filename)
$NewController2 = New-ScsiController -HardDisk $G_Drive2 -BusSharingMode Physical -Type ParaVirtual -Confirm:$false

#Change the SCSI ID of the moved disk
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Changing the SCSI ID of the G drive from 2 to 0..."
$SecondNode = Get-VM $($DataFromFile2.VMInfo.VMName)
$G_Drive2 = Get-VM $($DataFromFile2.VMInfo.VMName) | Get-HardDisk | Where-Object { $_.Name -eq "Hard Disk 3" }
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = "edit"
$spec.deviceChange[0].device = $G_Drive2.ExtensionData
$spec.deviceChange[0].device.unitNumber = 0
$SecondNode.ExtensionData.ReconfigVM($spec)

#Adding additional disks listed in cluster config file
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating additional shared disks..."
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating Q drive on Node 1..."
$NewDisk = New-HardDisk -VM $FirstNode -Controller $NewController1 -CapacityGB 5 -StorageFormat EagerZeroedThick -Datastore $($DataFromFile3.ClusterInfo.DedicatedDS)
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding Q drive to Node 2..."
New-HardDisk -VM $SecondNode -Controller $NewController2 -DiskPath $($NewDisk.Filename) | Out-Null

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating M drive on Node 1..."
$NewDisk = New-HardDisk -VM $FirstNode -Controller $NewController1 -CapacityGB 5 -StorageFormat EagerZeroedThick -Datastore $($DataFromFile3.ClusterInfo.DedicatedDS)
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding M drive to Node 2..."
New-HardDisk -VM $SecondNode -Controller $NewController2 -DiskPath $($NewDisk.Filename) | Out-Null

foreach($DiskToAdd in $DisksToAdd)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating $($DiskToAdd.MPName) disk on Node 1..."
    $NewDisk = New-HardDisk -VM $FirstNode -Controller $NewController1 -CapacityGB $($DiskToAdd.Size) -StorageFormat EagerZeroedThick -Datastore $($DataFromFile3.ClusterInfo.DedicatedDS)
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding $($DiskToAdd.MPName) disk to Node 2..."
    New-HardDisk -VM $SecondNode -Controller $NewController2 -DiskPath $($NewDisk.Filename) | Out-Null
}

#Power the VMs on
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shared disks created. Powering on Node 1..."
Start-VM $FirstNode | Out-Null

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for VMware tools to start..."
$Ready = $false
while (!($Ready))
{
    $ToolsStatus = (Get-VM -Name $FirstNode).Guest.ExtensionData.ToolsStatus
    if ($ToolsStatus -eq "toolsOK" -or $ToolsStatus -eq "toolsOld") { $Ready = $true }
    Start-Sleep 5
}
Clear-Variable ToolsStatus

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Powering on Node 2..."
Start-VM $SecondNode | Out-Null

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for VMware tools to start..."
$Ready = $false
while (!($Ready))
{
    $ToolsStatus = (Get-VM -Name $SecondNode).Guest.ExtensionData.ToolsStatus
    if ($ToolsStatus -eq "toolsOK" -or $ToolsStatus -eq "toolsOld") { $Ready = $true }
    Start-Sleep 5
}
Clear-Variable ToolsStatus

#Initialize and Format all disks
$GuestDiskNumber = 2
$GuestVolumeNumber = 4

#G Drive
$ScriptText = "ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Disk $GuestDiskNumber >> C:\DiskPart.txt && ECHO attributes disk clear readonly >> C:\DiskPart.txt && ECHO online disk >> C:\DiskPart.txt && ECHO convert gpt >> C:\DiskPart.txt && ECHO create partition primary >> C:\DiskPart.txt && ECHO select partition 1 >> C:\DiskPart.txt && ECHO select volume $GuestVolumeNumber >> C:\DiskPart.txt && ECHO format FS=NTFS label=MPRoot QUICK >> C:\DiskPart.txt && ECHO assign letter=G >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q"
$DiskPartOutput = Invoke-VMScript -VM $FirstNode -ScriptText $ScriptText -ScriptType BAT -GuestCredential $DomainCredentials
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $DiskPartOutput

$GuestVolumeNumber++
$GuestDiskNumber++

#Q Drive
$ScriptText = "ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Disk $GuestDiskNumber >> C:\DiskPart.txt && ECHO attributes disk clear readonly >> C:\DiskPart.txt && ECHO online disk >> C:\DiskPart.txt && ECHO convert gpt >> C:\DiskPart.txt && ECHO create partition primary >> C:\DiskPart.txt && ECHO select partition 1 >> C:\DiskPart.txt && ECHO select volume $GuestVolumeNumber >> C:\DiskPart.txt && ECHO format FS=NTFS label=QUORUM QUICK >> C:\DiskPart.txt && ECHO assign letter=Q >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q"
$DiskPartOutput = Invoke-VMScript -VM $FirstNode -ScriptText $ScriptText -ScriptType BAT -GuestCredential $DomainCredentials
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $DiskPartOutput

$GuestVolumeNumber++
$GuestDiskNumber++

#M Drive
$ScriptText = "ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Disk $GuestDiskNumber >> C:\DiskPart.txt && ECHO attributes disk clear readonly >> C:\DiskPart.txt && ECHO convert gpt >> C:\DiskPart.txt && ECHO create partition primary >> C:\DiskPart.txt && ECHO select partition 1 >> C:\DiskPart.txt && ECHO select volume $GuestVolumeNumber >> C:\DiskPart.txt && ECHO format FS=NTFS label=MSDTC QUICK >> C:\DiskPart.txt && ECHO assign letter=M >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q"
$DiskPartOutput = Invoke-VMScript -VM $FirstNode -ScriptText $ScriptText -ScriptType BAT -GuestCredential $DomainCredentials
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $DiskPartOutput

$GuestVolumeNumber++
$GuestDiskNumber++

foreach ($DiskToAdd in $DisksToAdd)
{
    $ScriptText = "mkdir G:\$($DiskToAdd.MPName) && ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Disk $GuestDiskNumber >> C:\DiskPart.txt && ECHO attributes disk clear readonly >> C:\DiskPart.txt && ECHO online disk >> C:\DiskPart.txt && ECHO convert gpt >> C:\DiskPart.txt && ECHO create partition primary >> C:\DiskPart.txt && ECHO select partition 1 >> C:\DiskPart.txt && ECHO select volume $GuestVolumeNumber >> C:\DiskPart.txt && ECHO format FS=NTFS label=$($DiskToAdd.MPName) QUICK >> C:\DiskPart.txt && ECHO assign mount=G:\$($DiskToAdd.MPName) >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q"
    $DiskPartOutput = Invoke-VMScript -VM $FirstNode -ScriptText $ScriptText -ScriptType BAT -GuestCredential $DomainCredentials
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $DiskPartOutput

    $GuestVolumeNumber++
    $GuestDiskNumber++
}
