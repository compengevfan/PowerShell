[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] $DomainCredentials = $null,
    [Parameter()] $SendEmail = $true
)

##################
#System Variables
##################
$ErrorActionPreference = "SilentlyContinue"
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false

#Import functions
. .\Functions\function_Get-FileName
. .\Functions\function_Get-FolderByPath
. .\Functions\function_Find-VmByAddress
. .\Functions\function_DoLogging
. .\Functions\function_ConvertToDN
. .\Functions\function_Check-PowerCLI.ps1

#if there is no input file, present an explorer window for the user to select one.
if ($InputFile -eq "" -or $InputFile -eq $null) { cls; Write-Host "Please select a JSON file..."; $InputFile = Get-FileName }

$InputFileName = Get-Item $InputFile | % {$_.BaseName}
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "Cloud-O-MITE@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

if (!(Test-Path .\~Logs)) { New-Item -Name "Logs" -ItemType Directory | Out-Null }

##################
#Check for VMware
##################

Check-PowerCLI

##################
#Check for Active Directory Module
##################

if (!(Get-Module -Name ActiveDirectory)) { Import-Module ActiveDirectory }

##################
#Check for vCenter Connection
##################

#$ConnectedvCenter = $global:DefaultVIServers
#if ($ConnectedvCenter -ne $null)
#{
#    $ConnectionResponse = Read-Host "You are already connected to $ConnectedvCenter. Use existing connection? (y/n)"
#    if ($ConnectionResponse -eq "n") { Disconnect-VIServer -Force -Confirm:$false }
#}

#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -LogType Info -LogString "Importing JSON Data File: $InputFile..."
$DataFromFile = ConvertFrom-JSON (Get-Content $InputFile -raw)
if ($DataFromFile -eq $null) { DoLogging -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

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

##################
#Obtain credentials needed to modify guest OS, add to domain and change OU.
##################

if ($DomainCredentials -eq $null)
{
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
}

##################
#Gather VM Specs from JSON File
##################

#Find the template to be used based on site and OS version from JSON. If template not found, exit.
$TemplateToFind = "TPL_" + $($DataFromFile.VMInfo.Cluster) + "_" + $($DataFromFile.GuestInfo.OS)
DoLogging -LogType Info -LogString "Locating Template $TemplateToFind"
$TemplateToUse = Get-Template $TemplateToFind
if ($TemplateToUse -ne $null) { DoLogging -LogType Succ -LogString "Template found..." }
else { DoLogging -LogType Err -LogString "Template NOT found!!! Script Exiting!!!"; exit }

#Find the Folder. If it is not found, exit.
DoLogging -LogType Info -LogString "Parsing folder path to find proper location..."
$Folder = $null
$Folder = Get-FolderByPath -Path $($DataFromFile.VMInfo.FolderPath)
if ($Folder -ne $null) { DoLogging -LogType Succ -LogString "Location found..." }
else { DoLogging -LogType Err -LogString "Location NOT found!!! Script Exiting!!!"; exit }

#Find the customization spec. If it is not found, exit.
DoLogging -LogType Info -LogString "Locating Customization Spec $($DataFromFile.GuestInfo.CustomizationSpec)..."
$OSCustSpec = Get-OSCustomizationSpec $($DataFromFile.GuestInfo.CustomizationSpec)
if ($OSCustSpec -ne $null) { DoLogging -LogType Succ -LogString "Customization Spec found..." }
else { DoLogging -LogType Err -LogString "Customization Spec NOT found!!! Script Exiting!!!"; exit }

#Find the Portgroup. Check for vDS first; if not found, check for standard. If it is not found, exit.
DoLogging -LogType Info -LogString "Locating PortGroup $($DataFromFile.VMInfo.PortGroup)..."
$PortGroup = Get-Datacenter $($DataFromFile.VMInfo.DataCenter) | Get-VDSwitch | Get-VDPortgroup $($DataFromFile.VMInfo.PortGroup)
if ($PortGroup -ne $null) { DoLogging -LogType Succ -LogString "PortGroup found..."; $PortType = "vds" }
if ($PortGroup -eq $null)
{
    $PortGroup = Get-Datacenter $($DataFromFile.VMInfo.DataCenter) | Get-VirtualPortGroup | where Name -eq $($DataFromFile.VMInfo.PortGroup)
    if ($PortGroup -ne $null) { DoLogging -LogType Succ -LogString "PortGroup found..."; $PortType = "std" }
    else { DoLogging -LogType Err -LogString "PortGroup NOT found!!! Script Exiting!!!"; exit }
}

#Find the Datastore. First, look for a DS Cluster. If not found, look for DS. If it is not found, exit.
DoLogging -LogType Info -LogString "Locating Datastore Cluster $($DataFromFile.VMInfo.Datastore)..."
$DataStore = Get-DatastoreCluster $($DataFromFile.VMInfo.Datastore)
if ($DataStore -eq $null) { $DataStore = Get-Datastore $($DataFromFile.VMInfo.Datastore) }
if ($DataStore -ne $null) { DoLogging -LogType Succ -LogString "Storage found..." }
else { DoLogging -LogType Err -LogString "Storage NOT found!!! Script Exiting!!!"; exit }

##################
#Perform Sanity Checks (Name not in use, IP not in use, etc)
##################

#Verify that VM name does not exist
$CheckName = Get-VM $($DataFromFile.VMInfo.VMName)
if ($CheckName -eq $null) { DoLogging -LogType Succ -LogString "New VM name not found..." }
else { DoLogging -LogType Err -LogString "New VM name found!!! Script Exiting!!!"; exit }

#Verify that the IP address is not one of the first 20 IPs in the subnet.

#Verify that IP address is not assigned to another VM.
$CheckIPAddress = Find-VmByAddress -IP $($DataFromFile.GuestInfo.IPaddress)
if ($CheckIPAddress -eq $null) { DoLogging -LogType Succ -LogString "New VM IP not found..." }
else { DoLogging -LogType Err -LogString "New VM IP found!!! Script Exiting!!!"; exit }

#Verify that the IP address does not respond to ping.
$CheckIPAddress = Test-Connection $($DataFromFile.GuestInfo.IPaddress) -Count 1
if ($CheckIPAddress -eq $null) { DoLogging -LogType Succ -LogString "New VM IP does not respond to ping..." }
else { DoLogging -LogType Err -LogString "New VM IP does respond to ping!!! Script Exiting!!!"; exit }

##################
#Display VM Info for verification before build
##################

##################
#Build/Customize/Configure VM
##################

#Create a temporary Customization Spec with appropriate network settings and domain information
DoLogging -LogType Info -LogString "Creating temporary customization spec..."
if ((Get-OSCustomizationSpec -Name $($DataFromFile.VMInfo.VMName)) -ne $null) { Remove-OSCustomizationSpec -OSCustomizationSpec $($DataFromFile.VMInfo.VMName) -Confirm:$false }
$TempCustomizationSpec = New-OSCustomizationSpec -Name $($DataFromFile.VMInfo.VMName) -Spec ( Get-OSCustomizationSpec -Name $OSCustSpec )
DoLogging -LogType Info -LogString "Configuring domain settings in temporary customization spec..."
$TempCustomizationSpec | Set-OSCustomizationSpec -Domain $($DataFromFile.GuestInfo.Domain) -DomainCredentials $DomainCredentials -AutoLogonCount 0 | Out-Null
DoLogging -LogType Info -LogString "Configuring network settings in temporary customization spec..."
$TempCustomizationSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress ($($DataFromFile.GuestInfo.IPAddress)) -SubnetMask ($($DataFromFile.GuestInfo.SubnetMask)) -DefaultGateway ($($DataFromFile.GuestInfo.Gateway)) -Dns ($($DataFromFile.GuestInfo.DNS1)),($($DataFromFile.GuestInfo.DNS2)) | Out-Null

#Create the VM
DoLogging -LogType Info -LogString "Deploying VM..."
New-VM -Name $($DataFromFile.VMInfo.VMName) -Template $TemplateToUse -ResourcePool $($DataFromFile.VMInfo.Cluster) -Datastore $DataStore -Location $Folder -OSCustomizationSpec $TempCustomizationSpec | Out-Null

Start-Sleep 5

#Verify VM Deployed, update specs, power on and wait for customization to complete.
if ((Get-VM $($DataFromFile.VMInfo.VMName)) -eq $null) { DoLogging -LogType Err -LogString "VM Deploy failed!!! Script exiting!!!";exit }
else
{
    DoLogging -LogType Info -LogString "Updating VM Specs..."
    $Notes = "Deployed by " + (whoami) + " via Dupree's Script: " + (Get-Date -Format g)
    Get-VM $($DataFromFile.VMInfo.VMName) | Set-VM -MemoryGB $($DataFromFile.GuestInfo.RAM) -NumCpu $($DataFromFile.GuestInfo.vCPUs) -Description $Notes -Confirm:$false | Out-Null
    switch ($PortType) 
    {
        vds { Get-NetworkAdapter -VM $($DataFromFile.VMInfo.VMName) | where Name -eq "Network adapter 1" | Set-NetworkAdapter -PortGroup $PortGroup -Confirm:$false | Set-NetworkAdapter -StartConnected:$true -Confirm:$false | Out-Null }
        std { $PortGroup = (Get-VM $($DataFromFile.VMInfo.VMName)).VMHost | Get-VirtualPortGroup | where name -eq ($PortGroup.Name | select -First 1); Get-NetworkAdapter -VM $($DataFromFile.VMInfo.VMName) | where Name -eq "Network adapter 1" | Set-NetworkAdapter -PortGroup $PortGroup -Confirm:$false | Set-NetworkAdapter -StartConnected:$true -Confirm:$false | Out-Null }
    }
    DoLogging -LogType Info -LogString "Checking for an optical drive..."
    if (!(Get-CDDrive -VM $($DataFromFile.VMInfo.VMName))) { DoLogging -LogType Info -LogString "Adding optical drive..."; New-CDDrive -VM $($DataFromFile.VMInfo.VMName) -Confirm:$false | Out-Null }
    else { DoLogging -LogType Info -LogString "VM already has an optical drive..." }
    Start-Sleep 5

    DoLogging -LogType Info -LogString "Powering on VM..."
    Start-VM $($DataFromFile.VMInfo.VMName) | Out-Null
    DoLogging -LogType Info -LogString "Waiting for customization to start..."
	    while($True)
	    {
		    $vmEvents = Get-VIEvent -Entity $($DataFromFile.VMInfo.VMName)
		    $startedEvent = $vmEvents | Where { $_.GetType().Name -eq "CustomizationStartedEvent" }
 
		    if ($startedEvent)
		    {
			    break	
		    }
 
		    else 	
		    {
			    Start-Sleep -Seconds 10
		    }
	    }
 
    DoLogging -LogType Info -LogString "Customization has started. Waiting for it to complete..."
	    while($True)
	    {
		    $vmEvents = Get-VIEvent -Entity $($DataFromFile.VMInfo.VMName)
		    $SucceededEvent = $vmEvents | Where { $_.GetType().Name -eq "CustomizationSucceeded" }
            $FailureEvent = $vmEvents | Where { $_.GetType().Name -eq "CustomizationFailed" }
 
		    if ($FailureEvent)
		    {
			    DoLogging -LogType Err -LogString -Message "Customization of VM failed!!! Script exiting!!!";exit
		    }
 
		    if ($SucceededEvent)
		    {
                break
		    }
            Start-Sleep -Seconds 5
	    }
    DoLogging -LogType Succ -LogString "Customization of VM Completed Successfully..."
}

DoLogging -LogType Info -LogString "Removing temporary customization spec..."
Remove-OSCustomizationSpec -OSCustomizationSpec $($DataFromFile.VMInfo.VMName) -Confirm:$false

DoLogging -LogType Info -LogString "Waiting a while after customization for Windows to stabilize..."
Start-Sleep 300

#Move server to appropriate OU, if OU in the JSON does not exist, the server gets moved to the "Servers" OU.
DoLogging -LogType Info -LogString "Verifying OU '$($DataFromFile.GuestInfo.OU)' exists..."
$DN = ConvertToDN -OUPath $($DataFromFile.GuestInfo.OU) -Domain $($DataFromFile.GuestInfo.Domain)
$OUCheck = Get-ADOrganizationalUnit -Identity $DN -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials
if ($OUCheck)
{
    DoLogging -LogType Info -LogString "Moving server to OU '$($DataFromFile.GuestInfo.OU)'..."
    Get-ADComputer -Identity $($DataFromFile.VMInfo.VMName) -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials | Move-ADObject -TargetPath $DN -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials
}
else
{
    DoLogging -LogType Warn -LogString "OU '$($DataFromFile.GuestInfo.OU)' does not exist!!! Moving server to 'servers' OU..."
    $DN = ConvertToDN -OUPath "Servers" -Domain $($DataFromFile.GuestInfo.Domain)
    Get-ADComputer -Identity $($DataFromFile.VMInfo.VMName) -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials | Move-ADObject -TargetPath $DN -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials
}

#Move JSON file to the processed folder.
DoLogging -LogType Info -LogString "Moving JSON to the 'processed' folder..."
$FileToMove = Get-Item $InputFile
Move-Item -Path $FileToMove -Destination .\~Processed-JSON-Files -Force

DoLogging -LogType Succ -LogString "Your VM has been successfully deployed!!!"
if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $InputFileName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Cloud-O-Mite Deployed a VM" -body $EmailBody }
