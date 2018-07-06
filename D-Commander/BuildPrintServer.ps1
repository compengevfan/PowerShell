[CmdletBinding()]
Param(
    [Parameter()] [string] $VMFile,
    [Parameter()] $SendEmail = $true
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath

$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
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
 
Check-PowerCLI
Connect-vCenter

##############################################################################################################################

if ($VMFile -eq "" -or $VMFile -eq $null) { cls; Write-Host "Please select a JSON file..."; $VMFile = Get-FileName }

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "BuildPrintServer@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
if (!(Test-Path .\~Processed-JSON-Files)) { New-Item -Name "~Processed-JSON-Files" -ItemType Directory | Out-Null }

cls
#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $VMFile..."
$DataFromFile = ConvertFrom-JSON (Get-Content $VMFile -raw)
if ($DataFromFile -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#If not connected to a vCenter, connect.
Connect-vCenter $($DataFromFile.VMInfo.vCenter)

##################
#Obtain local credentials needed to modify the guest OS
##################

#$LocalCreds = Get-Credential -Message "Please provide the username and password for the local Administrator account."

##################
#Obtain domain credentials
##################

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

$SecurityGroups = Import-Csv .\BuildPrintServer-Data.csv

ForEach($SecurityGroup in $SecurityGroups)
{
    $ScriptText = @'
    	$DomainName = "#SecurityGroup.Domain"
	    $GroupName = "#SecurityGroup.Group"
	    $AdminGroup = [ADSI]"WinNT://localhost/Administrators,group"
	    $Group = [ADSI]"WinNT://$DomainName/$GroupName,group"
	    $AdminGroup.Add($Group.Path)
'@
    $ScriptText = $ScriptText.Replace('#SecurityGroup.Domain',$($SecurityGroup.Domain)).Replace('#SecurityGroup.Group',$($SecurityGroup.Group))
    $InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $ScriptText -GuestCredential $DomainCredentials -ScriptType Powershell
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput
}

$Command = "Install-WindowsFeature Print-Services -IncludeAllSubFeature -IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Triggering server restart to complete the feature install..."
Restart-VM -VM $($DataFromFile.VMInfo.VMName) -Confirm:$false

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Your print server has been successfully configured!!!"
if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Print Server Deployed!!!" -body $EmailBody }
