[CmdletBinding()]
Param(
    [Parameter()] [string] $VMFile,
    [Parameter()] [string] $FSFile,
    [Parameter()] $SendEmail = $true
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
Connect-DFvCenter

##############################################################################################################################

if ($VMFile -eq "" -or $VMFile -eq $null) { cls; Write-Host "Please select a VM config JSON file..."; $VMFile = Get-DfFileName -Filter "json" }

if ($FSFile -eq "" -or $FSFile -eq $null) { cls; Write-Host "Please select a File Server config JSON file..."; $FSFile = Get-DfFileName -Filter "json" }

##################
#Email Variables
##################
#emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "BuildFileServer@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
if (!(Test-Path .\~Processed-JSON-Files)) { New-Item -Name "~Processed-JSON-Files" -ItemType Directory | Out-Null }

cls
#Check to make sure we have a JSON file location and if so, get the info.
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $VMFile..."
$DataFromFile = ConvertFrom-JSON (Get-Content $VMFile -raw)
if ($DataFromFile -eq $null) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Check to make sure we have a JSON file location and if so, get the info.
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $FSFile..."
$DataFromFile2 = ConvertFrom-JSON (Get-Content $FSFile -raw)
if ($DataFromFile2 -eq $null) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Get the array of disks from the json file and verify that it's not too many...
$DisksToAdd = $DataFromFile2.DiskLayout
if ($DisksToAdd.Count -gt 23) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "This script doesn't support more than 23 data disks, including the G Drive. Please build VM with Cloud-o-MITE and add disks manually or reduce the number of data disks."; exit }

#If not connected to a vCenter, connect.
Connect-DFvCenter $($DataFromFile.VMInfo.vCenter)

if ($DomainCredentials -eq $null)
{
    while($true)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Obtaining Domain Credentials. Note: Username MUST be in 'user principle name' format. For example: me@domain.com"
        $DomainCredentials = Get-Credential -Message "READ ME!!! Please provide a username and password for the $($DataFromFile.GuestInfo.Domain) domain. Username MUST be in 'user principle name' format. For example: me@domain.com"
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Testing domain credentials..."
        #Verify Domain Credentials
        $username = $DomainCredentials.username
        $password = $DomainCredentials.GetNetworkCredential().password

        # Get current domain using logged-on user's credentials
        $CurrentDomain = "LDAP://" + $($DataFromFile.GuestInfo.Domain)
        $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

        if ($domain.name -eq $null) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Domain Credentials Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
        else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Credential test was successful..."; break }
    }
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Calling Cloud-O-MITE to build the VM..."
$Code = .\Cloud-O-MITE.ps1 -InputFile $VMFile -DomainCredentials $DomainCredentials
if ($Code -eq 66) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "VM build failed. Exiting build script."; exit }

$DiskNumber = 2
$VolumeNumber = 4

#Loop through all the disks and update/add them.
foreach ($DiskToAdd in $DisksToAdd)
{
    if ($DiskNumber -eq 2 -and $($DiskToAdd.Size) -le 10) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "G Drive will not be resized..." }
    elseif ($DiskNumber -eq 2)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Expanding G drive to $($DiskToAdd.Size) GB..."
        Get-HardDisk -VM $($DataFromFile.VMInfo.VMName) | where {$_.Name -eq "Hard disk 3"} | Set-HardDisk -CapacityGB $($DiskToAdd.Size) -Confirm:$false | Out-Null
        Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText "ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Volume G >> C:\DiskPart.txt && ECHO EXTEND >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q" -ScriptType BAT -GuestCredential $DomainCredentials
    }

    if ($($DiskToAdd.DriveLetter) -eq "C" -or $($DiskToAdd.DriveLetter) -eq "D" -or $($DiskToAdd.DriveLetter) -eq "P")
    { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Drive letters C, D and P are already in use. Skipping..." }
    elseif ($DiskNumber -ne 2)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding drive $($DiskToAdd.DriveLetter)..."
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
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $DiskPartOutput
    }

    $VolumeNumber++
    $DiskNumber++
}

#Add File Server Roles to Server
$Command = "Install-WindowsFeature FS-FileServer -IncludeAllSubFeature -IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput

$Command = "Install-WindowsFeature FS-Resource-Manager -IncludeAllSubFeature -IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput

$Command = "Install-WindowsFeature Storage-Services -IncludeAllSubFeature -IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput

#Move JSON file to the processed folder.
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Moving JSON to the 'processed' folder..."
$FileToMove = Get-Item $FSFile
Move-Item -Path $FileToMove -Destination .\~Processed-JSON-Files -Force

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Triggering server restart to complete the feature install..."
Restart-VMGuest -VM $($DataFromFile.VMInfo.VMName) -Confirm:$false

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Your file server has been successfully configured!!!"
if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "File Server Deployed!!!" -body $EmailBody }
