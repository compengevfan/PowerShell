#Stuff from Cloud-O-MITE

##################
#Obtain local credentials needed to modify the guest OS
##################

$LocalCreds = Get-Credential -Message "Please provide the username and password for the local Administrator account."

##################
#Obtain domain credentials
##################

while($true)
{
    DoLogging -LogType Warn -LogString "Obtaining Domain Credentials. Note: Username MUST be in 'user principle name' format. For example: me@domain.com"
	$DomainCredentials = Get-Credential -Message "READ ME!!! Please provide the username and password for joining the $($DataFromFile.GuestInfo.Domain) domain. Username MUST be in 'user principle name' format. For example: me@domain.com"
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

#Test Local Creds
while($true)
{
    $Output = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText "cd C:\Windows" -ScriptType BAT -GuestCredential $LocalCreds

    if ($Output -eq $null) 
    {
        DoLogging -LogType Warn -LogString "Local Credentials Failed!!! Please provide proper credentials..."
        $LocalCreds = Get-Credential -Message "Please provide the username and password for the local Administrator account."
    }
    else { break }
}

#Add mount points or set the G Drive to the desired size
if ($($DataFromFile.GuestInfo.MountPoints) -eq "Yes")
{
    DoLogging -LogType Info -LogString "Mount points are being added so G drive will not be resized. Adding mount points..."

    #Get the array of disks from the json file.
    $DisksToAdd = $DataFromFile.AdditionalDisks

    $DiskNumber = 3
    $VolumeNumber = 5
    $SCSI_ID = 3

    #Loop through all the new disks and add them.
    foreach ($DiskToAdd in $DisksToAdd)
    {
        New-HardDisk -VM $($DataFromFile.VMInfo.VMName) -CapacityGB $($DiskToAdd.Size) -StorageFormat Thick | Out-Null

        if ($($DataFromFile.GuestInfo.OS) -eq "2K12R2")
        {
            $ScriptText = "mkdir G:\$($DiskToAdd.MPName) && ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Disk $DiskNumber >> C:\DiskPart.txt && ECHO attributes disk clear readonly >> C:\DiskPart.txt && ECHO online disk >> C:\DiskPart.txt && ECHO convert gpt >> C:\DiskPart.txt && ECHO create partition primary >> C:\DiskPart.txt && ECHO select partition 1 >> C:\DiskPart.txt && ECHO select volume $VolumeNumber >> C:\DiskPart.txt && ECHO format FS=NTFS label=$($DiskToAdd.MPName) QUICK >> C:\DiskPart.txt && ECHO assign mount=G:\$($DiskToAdd.MPName) >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q"
        }
        elseif ($($DataFromFile.GuestInfo.OS) -eq "2K8R2")
        {
            $ScriptText = "mkdir G:\$($DiskToAdd.MPName) && ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Disk $DiskNumber >> C:\DiskPart.txt && ECHO attributes disk clear readonly >> C:\DiskPart.txt && ECHO convert gpt >> C:\DiskPart.txt && ECHO create partition primary >> C:\DiskPart.txt && ECHO select partition 1 >> C:\DiskPart.txt && ECHO select volume $VolumeNumber >> C:\DiskPart.txt && ECHO format FS=NTFS label=$($DiskToAdd.MPName) QUICK >> C:\DiskPart.txt && ECHO assign mount=G:\$($DiskToAdd.MPName) >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q"
        }
        $DiskPartOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $ScriptText -ScriptType BAT -GuestCredential $LocalCreds
        DoLogging -LogType Info -LogString $DiskPartOutput

        $VolumeNumber++
        $DiskNumber++
    }
}
elseif ($($DataFromFile.GuestInfo.G_Drive) -le 10) { DoLogging -LogType Info -LogString "G Drive will not be resized..." }
else
{
    DoLogging -LogType Info -LogString "Expanding G drive to $($DataFromFile.GuestInfo.G_Drive) GB..."
    Get-HardDisk -VM $($DataFromFile.VMInfo.VMName) | where {$_.Name -eq "Hard disk 3"} | Set-HardDisk -CapacityGB $($DataFromFile.GuestInfo.G_Drive) -Confirm:$false | Out-Null
    Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText "ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Volume G >> C:\DiskPart.txt && ECHO EXTEND >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q" -ScriptType BAT -GuestCredential $LocalCreds
}