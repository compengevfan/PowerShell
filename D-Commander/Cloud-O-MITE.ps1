[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] [PSCredential] $DomainCredentials = $null,
    [Parameter()] $SendEmail = $True
)

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath

$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

$LoggingSuccSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Succ"}
$LoggingInfoSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Info"}
$LoggingWarnSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Warn"}
$LoggingErrSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Err"}
 
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
 
Import-PowerCLI

##############################################################################################################################

#if there is no input file, present an explorer window for the user to select one.
if ($InputFile -eq "" -or $null -eq $InputFile) { Clear-Host; Write-Host "Please select a JSON file..."; $InputFile = Get-FileName -Filter "json" }

##################
#Email Variables
##################
#emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "Cloud-O-MITE@evorigin.com"
$emailTo = "chris.dupree@gmail.com"
$emailServer = "smtp.gmail.com"

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
if (!(Test-Path .\~Processed-JSON-Files)) { New-Item -Name "~Processed-JSON-Files" -ItemType Directory | Out-Null }

##################
#Check for Active Directory Module
##################

if (!(Get-Module -Name ActiveDirectory)) { Import-Module ActiveDirectory }

#Check to make sure we have a JSON file location and if so, get the info.
Invoke-Logging @LoggingInfoSplat -LogString "Importing JSON Data File: $InputFile..."
$DataFromFile = ConvertFrom-JSON (Get-Content $githome\vmbuildfiles\$InputFile -raw)
if ($null -eq $DataFromFile) { Invoke-Logging @LoggingErrSplat -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Connect-vCenter $($DataFromFile.VMInfo.vCenter)

##################
#Obtain credentials needed to modify guest OS, add to domain and change OU.
##################

if ($($DataFromFile.GuestInfo.Domain) -ne "none") {
    while ($true) {
        if ($null -eq $DomainCredentials) {
            Invoke-Logging @LoggingWarnSplat -LogString "Obtaining Domain Credentials. Note: Username MUST be in 'user principle name' format. For example: me@domain.com"
            $DomainCredentials = Get-Credential -Message "READ ME!!! Please provide the username and password for joining the $($DataFromFile.GuestInfo.Domain) domain. Username MUST be in 'user principle name' format. For example: me@domain.com"
        }
        Invoke-Logging @LoggingInfoSplat -LogString "Testing domain credentials..."
        #Verify Domain Credentials
        $username = $DomainCredentials.username
        $password = $DomainCredentials.GetNetworkCredential().password

        # Get current domain using logged-on user's credentials
        $CurrentDomain = "LDAP://" + $($DataFromFile.GuestInfo.Domain)
        $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain, $UserName, $Password)

        if ($null -eq $domain.name) { Invoke-Logging @LoggingWarnSplat -LogString "Domain Credentials Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
        else { Invoke-Logging @LoggingSuccSplat -LogString "Credential test was successful..."; break }
    }
}

##################
#Gather VM Specs from JSON File
##################

#Find the template to be used based on site and OS version from JSON. If template not found, exit.
$TemplateToFind = $($DataFromFile.VMInfo.Template)
Invoke-Logging @LoggingInfoSplat -LogString "Locating Template $TemplateToFind"
$TemplateToUse = Get-Template $TemplateToFind -ErrorAction Ignore
if ($null -ne $TemplateToUse) { Invoke-Logging @LoggingSuccSplat -LogString "Template found..." }
else { Invoke-Logging @LoggingErrSplat -LogString "Template NOT found!!! Script Exiting!!!"; return 66 }

#Find the Folder. If it is not found, exit.
Invoke-Logging @LoggingInfoSplat -LogString "Parsing folder path to find proper location..."
$Folder = $null
$Folder = Get-FolderByPath -Path $($DataFromFile.VMInfo.FolderPath) -ErrorAction Ignore
if ($null -ne $Folder) { Invoke-Logging @LoggingSuccSplat -LogString "Location found..." }
else { Invoke-Logging @LoggingErrSplat -LogString "Location NOT found!!! Script Exiting!!!"; return 66 }

#Find the customization spec. If it is not found, exit.
Invoke-Logging @LoggingInfoSplat -LogString "Locating Customization Spec $($DataFromFile.GuestInfo.CustomizationSpec)..."
$OSCustSpec = Get-OSCustomizationSpec $($DataFromFile.GuestInfo.CustomizationSpec) -ErrorAction Ignore
if ($null -ne $OSCustSpec) { Invoke-Logging @LoggingSuccSplat -LogString "Customization Spec found..." }
else { Invoke-Logging @LoggingErrSplat -LogString "Customization Spec NOT found!!! Script Exiting!!!"; return 66 }

#Find the Portgroup. Check for vDS first; if not found, check for standard. If it is not found, exit.
Invoke-Logging @LoggingInfoSplat -LogString "Locating PortGroup $($DataFromFile.VMInfo.PortGroup)..."
$PortGroup = Get-Datacenter $($DataFromFile.VMInfo.DataCenter) | Get-VDSwitch | Get-VDPortgroup $($DataFromFile.VMInfo.PortGroup) -ErrorAction Ignore
if ($null -ne $PortGroup) { Invoke-Logging @LoggingSuccSplat -LogString "PortGroup found..."; $PortType = "vds" }
if ($null -eq $PortGroup) {
    $PortGroup = Get-Datacenter $($DataFromFile.VMInfo.DataCenter) | Get-VirtualPortGroup | Where-Object Name -eq $($DataFromFile.VMInfo.PortGroup) -ErrorAction Ignore
    if ($null -ne $PortGroup) { Invoke-Logging @LoggingSuccSplat -LogString "PortGroup found..."; $PortType = "std" }
    else { Invoke-Logging @LoggingErrSplat -LogString "PortGroup NOT found!!! Script Exiting!!!"; return 66 }
}

#Find the Datastore. First, look for a DS Cluster. If not found, look for DS. If it is not found, exit.
Invoke-Logging @LoggingInfoSplat -LogString "Locating Datastore Cluster $($DataFromFile.VMInfo.Datastore)..."
$DataStore = Get-DatastoreCluster $($DataFromFile.VMInfo.Datastore) -ErrorAction Ignore
if ($null -eq $DataStore) { $DataStore = Get-Datastore $($DataFromFile.VMInfo.Datastore) -ErrorAction Ignore }
if ($null -ne $DataStore) { Invoke-Logging @LoggingSuccSplat -LogString "Storage found..." }
else { Invoke-Logging @LoggingErrSplat -LogString "Storage NOT found!!! Script Exiting!!!"; return 66 }

##################
#Perform Sanity Checks (Name not in use, IP not in use, etc)
##################

$VmName = $InputFile.Replace(".json", "").ToUpper()

#Verify that VM name does not exist
$CheckName = Get-VM $VmName -ErrorAction Ignore
if ($null -eq $CheckName) { Invoke-Logging @LoggingSuccSplat -LogString "New VM name not found..." }
else { Invoke-Logging @LoggingErrSplat -LogString "New VM name found!!! Script Exiting!!!"; return 66 }

#Verify that the IP address is not one of the first 20 IPs in the subnet.

#Verify that IP address is not assigned to another VM.
$CheckIPAddress = Find-VmByAddress -IP $($DataFromFile.GuestInfo.IPaddress) -ErrorAction Ignore
if ($null -eq $CheckIPAddress) { Invoke-Logging @LoggingSuccSplat -LogString "New VM IP not found..." }
else { Invoke-Logging @LoggingErrSplat -LogString "New VM IP found!!! Script Exiting!!!"; return 66 }

#Verify that the IP address does not respond to ping.
$CheckIPAddress = Test-Connection $($DataFromFile.GuestInfo.IPaddress) -Count 1 -ErrorAction Ignore
if ($null -eq $CheckIPAddress) { Invoke-Logging @LoggingSuccSplat -LogString "New VM IP does not respond to ping..." }
else { Invoke-Logging @LoggingErrSplat -LogString "New VM IP does respond to ping!!! Script Exiting!!!"; return 66 }

##################
#Display VM Info for verification before build
##################

##################
#Build/Customize/Configure VM
##################

#Create a temporary Customization Spec with appropriate network settings and domain information
Invoke-Logging @LoggingInfoSplat -LogString "Creating temporary customization spec..."
if ($null -ne (Get-OSCustomizationSpec -Name $VmName -ErrorAction Ignore)) { Remove-OSCustomizationSpec -OSCustomizationSpec $VmName -Confirm:$false }
$TempCustomizationSpec = New-OSCustomizationSpec -Name $VmName -Spec ( Get-OSCustomizationSpec -Name $OSCustSpec )

if ($($DataFromFile.GuestInfo.Domain) -ne "none") {
    Invoke-Logging @LoggingInfoSplat -LogString "Configuring domain settings in temporary customization spec..."
    $TempCustomizationSpec | Set-OSCustomizationSpec -Domain $($DataFromFile.GuestInfo.Domain) -DomainCredentials $DomainCredentials -AutoLogonCount 0 | Out-Null
}

Invoke-Logging @LoggingInfoSplat -LogString "Configuring network settings in temporary customization spec..."
$TempCustomizationSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress ($($DataFromFile.GuestInfo.IPAddress)) -SubnetMask ($($DataFromFile.GuestInfo.SubnetMask)) -DefaultGateway ($($DataFromFile.GuestInfo.Gateway)) -Dns ($($DataFromFile.GuestInfo.DNS1)), ($($DataFromFile.GuestInfo.DNS2)) | Out-Null

#Create the VM
Invoke-Logging @LoggingInfoSplat -LogString "Deploying VM..."
New-VM -Name $VmName -Template $TemplateToUse -ResourcePool $($DataFromFile.VMInfo.Cluster) -Datastore $DataStore -Location $Folder -OSCustomizationSpec $TempCustomizationSpec -ErrorAction SilentlyContinue -ErrorVariable NewVMFail | Out-Null

Start-Sleep 5

#Verify VM Deployed, update specs, power on and wait for customization to complete.
if ($null -eq (Get-VM $VmName -ErrorAction SilentlyContinue)) { Invoke-Logging @LoggingErrSplat -LogString "VM Deploy failed!!! Script exiting!!!"; Invoke-Logging @LoggingErrSplat -LogString $NewVMFail; return 66 }
else {
    Invoke-Logging @LoggingInfoSplat -LogString "Updating VM Specs..."
    $Notes = "Deployed by " + (whoami) + " via Dupree's Script: " + (Get-Date -Format g)
    Get-VM $VmName | Set-VM -MemoryGB $($DataFromFile.GuestInfo.RAM) -NumCpu $($DataFromFile.GuestInfo.vCPUs) -Description $Notes -Confirm:$false | Out-Null
    switch ($PortType) {
        vds { Get-NetworkAdapter -VM $VmName | Where-Object Name -eq "Network adapter 1" | Set-NetworkAdapter -PortGroup $PortGroup -Confirm:$false | Set-NetworkAdapter -StartConnected:$true -Confirm:$false | Out-Null }
        std { $PortGroup = (Get-VM $VmName).VMHost | Get-VirtualPortGroup | Where-Object name -eq ($PortGroup.Name | Select-Object -First 1); Get-NetworkAdapter -VM $VmName | Where-Object Name -eq "Network adapter 1" | Set-NetworkAdapter -PortGroup $PortGroup -Confirm:$false | Set-NetworkAdapter -StartConnected:$true -Confirm:$false | Out-Null }
    }
    Invoke-Logging @LoggingInfoSplat -LogString "Checking for an optical drive..."
    if (!(Get-CDDrive -VM $VmName)) { Invoke-Logging @LoggingInfoSplat -LogString "Adding optical drive..."; New-CDDrive -VM $VmName -Confirm:$false | Out-Null }
    else { Invoke-Logging @LoggingInfoSplat -LogString "VM already has an optical drive..." }
    Start-Sleep 5

    Invoke-Logging @LoggingInfoSplat -LogString "Powering on VM..."
    Start-VM $VmName | Out-Null
    Invoke-Logging @LoggingInfoSplat -LogString "Waiting for customization to start..."
    while ($True) {
        $vmEvents = Get-VIEvent -Entity $VmName
        $startedEvent = $vmEvents | Where-Object { $_.GetType().Name -eq "CustomizationStartedEvent" }
 
        if ($startedEvent) {
            break	
        }
 
        else {
            Start-Sleep -Seconds 10
        }
    }
 
    Invoke-Logging @LoggingInfoSplat -LogString "Customization has started. Waiting for it to complete..."
    while ($True) {
        $vmEvents = Get-VIEvent -Entity $VmName
        $SucceededEvent = $vmEvents | Where-Object { $_.GetType().Name -eq "CustomizationSucceeded" }
        $FailureEvent = $vmEvents | Where-Object { $_.GetType().Name -eq "CustomizationFailed" }
 
        if ($FailureEvent) {
            Invoke-Logging @LoggingErrSplat -LogString -Message "Customization of VM failed!!! Script exiting!!!"; exit
        }
 
        if ($SucceededEvent) {
            break
        }
        Start-Sleep -Seconds 5
    }
    Invoke-Logging @LoggingSuccSplat -LogString "Customization of VM Completed Successfully..."
}

Invoke-Logging @LoggingInfoSplat -LogString "Removing temporary customization spec..."
Remove-OSCustomizationSpec -OSCustomizationSpec $VmName -Confirm:$false

Invoke-Logging @LoggingInfoSplat -LogString "Waiting a while after customization for Windows to stabilize..."
Start-Sleep 60

if ($($DataFromFile.GuestInfo.Domain) -ne "none") {
    #Move server to appropriate OU, if OU in the JSON does not exist, the server gets moved to the "Servers" OU.
    Invoke-Logging @LoggingInfoSplat -LogString "Verifying OU '$($DataFromFile.GuestInfo.OU)' exists..."
    $DN = ConvertToDN -OUPath $($DataFromFile.GuestInfo.OU) -Domain $($DataFromFile.GuestInfo.Domain)
    try {
        Get-ADOrganizationalUnit -Identity $DN -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials -ErrorAction SilentlyContinue
        Invoke-Logging @LoggingInfoSplat -LogString "Moving server to OU '$($DataFromFile.GuestInfo.OU)'..."
        Get-ADComputer -Identity $VmName -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials | Move-ADObject -TargetPath $DN -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials
    }
    catch {
        Invoke-Logging @LoggingWarnSplat -LogString "OU '$($DataFromFile.GuestInfo.OU)' does not exist!!! Moving server to 'servers' OU..."
        $DN = ConvertToDN -OUPath "Servers" -Domain $($DataFromFile.GuestInfo.Domain)
        Get-ADComputer -Identity $VmName -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials | Move-ADObject -TargetPath $DN -Server $($DataFromFile.GuestInfo.DNS1) -Credential $DomainCredentials
    }
}

Invoke-Logging @LoggingSuccSplat -LogString "Your VM has been successfully deployed!!!"
if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Cloud-O-Mite Deployed a VM" -body $EmailBody -Credential $CredGmail -UseSsl -port 587 }
