[CmdletBinding()]
Param(
    [Parameter()] [string] $VMFile,
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

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "BuildTerminalServer@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

Check-PowerCLI

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
if (!(Test-Path .\~Processed-JSON-Files)) { New-Item -Name "~Processed-JSON-Files" -ItemType Directory | Out-Null }

cls
#Check to make sure we have a JSON file location and if so, get the info.
DoLogging -LogType Info -LogString "Importing JSON Data File: $VMFile..."
$DataFromFile = ConvertFrom-JSON (Get-Content $VMFile -raw)
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

.\Cloud-O-MITE.ps1 -InputFile $VMFile -DomainCredentials $DomainCredentials

$DiskNumber = 2
$VolumeNumber = 4

#Expand G dive to 100GB
DoLogging -LogType Info -LogString "Expanding G drive to 100 GB..."
Get-HardDisk -VM $($DataFromFile.VMInfo.VMName) | where {$_.Name -eq "Hard disk 3"} | Set-HardDisk -CapacityGB 100 -Confirm:$false | Out-Null
Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText "ECHO RESCAN > C:\DiskPart.txt && ECHO SELECT Volume G >> C:\DiskPart.txt && ECHO EXTEND >> C:\DiskPart.txt && ECHO EXIT >> C:\DiskPart.txt && DiskPart.exe /s C:\DiskPart.txt && DEL C:\DiskPart.txt /Q" -ScriptType BAT -GuestCredential $DomainCredentials

#Add Terminal Server Role to Server
$Command = "Install-WindowsFeature RDS-RD-Server -IncludeAllSubFeature -IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
DoLogging -LogType Info -LogString $InvokeOutput

DoLogging -LogType Info -LogString "Triggering server restart to complete the feature install..."
Restart-VMGuest -VM $($DataFromFile.VMInfo.VMName) -Confirm:$false | Out-Null

#Wait for VMware tools to come back
$Ready = $false
while (!($Ready))
{
    $ToolsStatus = (Get-VM -Name $($DataFromFile.VMInfo.VMName)).Guest.ExtensionData.ToolsStatus
    if ($ToolsStatus -eq "toolsOK" -or $ToolsStatus -eq "toolsOld") { $Ready = $true }
    Start-Sleep 5
}

#Copy users and programdata folder from C to G
Start-Sleep 30
DoLogging -LogType Info -LogString "Copying 'Users\Public' folder from C drive to G drive..."
$Command = "robocopy C:\Users\Public G:\Users\Public /MIR /R:0 /W:0 /nfl /njh /njs /ndl /nc /ns"
Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell | Out-Null
##DoLogging -LogType Info -LogString $InvokeOutput

DoLogging -LogType Info -LogString "Copying 'ProgramData' folder from C drive to G drive..."
$Command = "robocopy c:\ProgramData g:\ProgramData /MIR /R:0 /W:0 /nfl /njh /njs /ndl /nc /ns"
Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell | Out-Null
#DoLogging -LogType Info -LogString $InvokeOutput

#Copy reg file to terminal server
DoLogging -LogType Info -LogString "Copying reg file to guest..."
Copy-VMGuestFile -Source .\TerminalServerRegKeys.reg -Destination C:\temp\ -Force -VM $($DataFromFile.VMInfo.VMName) -GuestCredential $DomainCredentials -LocalToGuest

$Command = "regedit.exe /s c:\temp\TerminalServerRegKeys.reg"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials
DoLogging -LogType Info -LogString $InvokeOutput

DoLogging -LogType Info -LogString "Triggering server restart to apply registry changes..."
Restart-VMGuest -VM $($DataFromFile.VMInfo.VMName) -Confirm:$false | Out-Null

DoLogging -LogType Succ -LogString "Your terminal server has been successfully configured!!!"
if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Terminal Server Deployed!!!" -body $EmailBody }
