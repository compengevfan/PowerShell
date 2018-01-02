[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] $SendEmail = $true
)

$ErrorActionPreference = "SilentlyContinue"

#Import functions
. .\Functions\function_Get-FileName.ps1
. .\Functions\function_DoLogging.ps1
. .\Functions\function_Check-PowerCLI.ps1

if ($InputFile -eq "" -or $InputFile -eq $null) { cls; Write-Host "Please select a JSON file..."; $InputFile = Get-FileName }

$InputFileName = Get-Item $InputFile | % {$_.BaseName}
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "BuildPrintServer@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

Check-PowerCLI

if (!(Test-Path .\~Logs)) { New-Item -Name "Logs" -ItemType Directory | Out-Null }

cls
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

.\Cloud-O-MITE.ps1 -InputFile $InputFile -DomainCredentials $DomainCredentials

$SecurityGroups = Import-Csv c:\temp\BuildPrintServer-Data.csv

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
    DoLogging -LogType Info -LogString $InvokeOutput
}

$Command = "Install-WindowsFeature Print-Services -IncludeAllSubFeature -IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
DoLogging -LogType Info -LogString $InvokeOutput

DoLogging -LogType Succ -LogString "Your print server has been successfully configured!!!"
if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $InputFileName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Print Server Deployed!!!" -body $EmailBody }
