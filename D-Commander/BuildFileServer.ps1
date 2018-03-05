[CmdletBinding()]
Param(
    [Parameter()] [string] $VMFile,
    [Parameter()] [string] $FSFile,
    [Parameter()] $SendEmail = $true
)

$ErrorActionPreference = "SilentlyContinue"

#Import functions
. .\Functions\function_Get-FileName.ps1
. .\Functions\function_DoLogging.ps1
. .\Functions\function_Check-PowerCLI.ps1

if ($VMFile -eq "" -or $VMFile -eq $null) { cls; Write-Host "Please select a VM config JSON file..."; $VMFile = Get-FileName }

$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

if ($FSFile -eq "" -or $FSFile -eq $null) { cls; Write-Host "Please select a File Server config JSON file..."; $FSFile = Get-FileName }

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "BuildFileServer@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

Check-PowerCLI

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
if (!(Test-Path .\~Processed-JSON-Files)) { New-Item -Name "~Processed-JSON-Files" -ItemType Directory | Out-Null }

cls
#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $VMFile..."
$DataFromFile = ConvertFrom-JSON (Get-Content $VMFile -raw)
if ($DataFromFile -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $FSFile..."
$DataFromFile2 = ConvertFrom-JSON (Get-Content $FSFile -raw)
if ($DataFromFile2 -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Get the array of disks from the json file and verify that it's not too many...
$DisksToAdd = $DataFromFile2.DiskLayout
if ($DisksToAdd.Count -gt 23) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "This script doesn't support more than 23 data disks, including the G Drive. Please build VM with Cloud-o-MITE and add disks manually or reduce the number of data disks."; exit }

#If not connected to a vCenter, connect.
$ConnectedvCenter = $global:DefaultVIServers
if ($ConnectedvCenter.Count -eq 0)
{
    do
    {
        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) {  DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Attempting to connect to vCenter server $($DataFromFile.VMInfo.vCenter)" }
        
        Connect-VIServer $($DataFromFile.VMInfo.vCenter) | Out-Null
        $ConnectedvCenter = $global:DefaultVIServers

        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null){ DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
    } while ($ConnectedvCenter.Count -eq 0)
}

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

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Calling Cloud-O-MITE to build the VM..."
$Code = .\Cloud-O-MITE.ps1 -InputFile $VMFile -DomainCredentials $DomainCredentials
if ($Code -eq 66) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "VM build failed. Exiting build script."; exit }

$DiskNumber = 2
$VolumeNumber = 4

#Loop through all the disks and update/add them.
foreach ($DiskToAdd in $DisksToAdd)
{
    if ($DiskNumber -eq 2 -and $($DiskToAdd.Size) -le 10) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "G Drive will not be resized..." }
    elseif ($DiskNumber -eq 2)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Expanding G drive to $($DiskToAdd.Size) GB..."
        Get-HardDisk -VM $($DataFromFile.VMInfo.VMName) | where {$_.Name -eq "Hard disk 3"} | Set-HardDisk -CapacityGB $($DiskToAdd.Size) -Confirm:$false | Out-Null
        Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText "ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Volume G >> C:\DiskPart.txt && ECHO EXTEND >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q" -ScriptType BAT -GuestCredential $DomainCredentials
    }

    if ($($DiskToAdd.DriveLetter) -eq "C" -or $($DiskToAdd.DriveLetter) -eq "D" -or $($DiskToAdd.DriveLetter) -eq "P")
    { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Drive letters C, D and P are already in use. Skipping..." }
    elseif ($DiskNumber -ne 2)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding drive $($DiskToAdd.DriveLetter)..."
        New-HardDisk -VM $($DataFromFile.VMInfo.VMName) -CapacityGB $($DiskToAdd.Size) -StorageFormat Thick | Out-Null

        if ($($DataFromFile.GuestInfo.OS) -eq "2K12R2")
        {
            $ScriptText = "ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Disk $DiskNumber >> C:\DiskPart.txt && ECHO attributes disk clear readonly >> C:\DiskPart.txt && ECHO online disk >> C:\DiskPart.txt && ECHO convert gpt >> C:\DiskPart.txt && ECHO create partition primary >> C:\DiskPart.txt && ECHO select partition 1 >> C:\DiskPart.txt && ECHO select volume $VolumeNumber >> C:\DiskPart.txt && ECHO format FS=NTFS QUICK >> C:\DiskPart.txt && ECHO assign letter=$($DiskToAdd.DriveLetter) >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q"
        }
        elseif ($($DataFromFile.GuestInfo.OS) -eq "2K8R2")
        {
            $ScriptText = "ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Disk $DiskNumber >> C:\DiskPart.txt && ECHO attributes disk clear readonly >> C:\DiskPart.txt && ECHO convert gpt >> C:\DiskPart.txt && ECHO create partition primary >> C:\DiskPart.txt && ECHO select partition 1 >> C:\DiskPart.txt && ECHO select volume $VolumeNumber >> C:\DiskPart.txt && ECHO format FS=NTFS QUICK >> C:\DiskPart.txt && ECHO assign letter=$($DiskToAdd.DriveLetter) >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q"
        }
        $DiskPartOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $ScriptText -ScriptType BAT -GuestCredential $DomainCredentials
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $DiskPartOutput
    }

    $VolumeNumber++
    $DiskNumber++
}

#Add File Server Roles to Server
$Command = "Install-WindowsFeature FS-FileServer -IncludeAllSubFeature -IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput

$Command = "Install-WindowsFeature FS-Resource-Manager -IncludeAllSubFeature -IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput

$Command = "Install-WindowsFeature Storage-Services -IncludeAllSubFeature -IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput

#Move JSON file to the processed folder.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Moving JSON to the 'processed' folder..."
$FileToMove = Get-Item $FSFile
Move-Item -Path $FileToMove -Destination .\~Processed-JSON-Files -Force

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Triggering server restart to complete the feature install..."
Restart-VMGuest -VM $($DataFromFile.VMInfo.VMName) -Confirm:$false

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Your file server has been successfully configured!!!"
if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "File Server Deployed!!!" -body $EmailBody }
