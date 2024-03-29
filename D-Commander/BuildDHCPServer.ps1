[CmdletBinding()]
Param(
    [Parameter()] [string] $VMFile,
    [Parameter()] [string] $DHCPFile,
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
 
##############################################################################################################################

if ($VMFile -eq "" -or $VMFile -eq $null) { cls; Write-Host "Please select a VM config JSON file..."; $VMFile = Get-DfFileName -Filter "json" }

if ($DHCPFile -eq "" -or $DHCPFile -eq $null) { cls; Write-Host "Please select a File Server config JSON file..."; $DHCPFile = Get-DfFileName -Filter "json" }

##################
#Email Variables
##################
#emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "BuildDHCPServer@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

Check-PowerCLI

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
if (!(Test-Path .\~Processed-JSON-Files)) { New-Item -Name "~Processed-JSON-Files" -ItemType Directory | Out-Null }

cls
#Check to make sure we have a JSON file location and if so, get the info.
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $VMFile..."
$DataFromFile = ConvertFrom-JSON (Get-Content $VMFile -raw)
if ($DataFromFile -eq $null) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#Check to make sure we have a JSON file location and if so, get the info.
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File: $DHCPFile..."
$DataFromFile2 = ConvertFrom-JSON (Get-Content $DHCPFile -raw)
if ($DataFromFile2 -eq $null) { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error importing JSON file. Please verify proper syntax and file name."; exit }

#If not connected to a vCenter, connect.
$ConnectedvCenter = $global:DefaultVIServers
if ($ConnectedvCenter.Count -eq 0)
{
    do
    {
        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) {  Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Attempting to connect to vCenter server $($DataFromFile.VMInfo.vCenter)" }
        
        Connect-VIServer $($DataFromFile.VMInfo.vCenter) | Out-Null
        $ConnectedvCenter = $global:DefaultVIServers

        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null){ Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
    } while ($ConnectedvCenter.Count -eq 0)
}

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

#Add DHCP Server Roles to Server
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Installing DHCP role..."
$Command = "Install-WindowsFeature DHCP �IncludeManagementTools"
$InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput

$Scopes = $DataFromFile2.Scopes

foreach($Scope in $Scopes)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding scope $($Scope.ScopeName)..."
    $Command = "Add-DhcpServerv4Scope -Name '$($Scope.ScopeName)' -StartRange $($Scope.StartIP) -EndRange $($Scope.EndIp) -SubnetMask $($Scope.SubnetMask)"
    $InvokeOutput = Invoke-VMScript -VM $($DataFromFile.VMInfo.VMName) -ScriptText $Command -GuestCredential $DomainCredentials -ScriptType Powershell
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString $InvokeOutput
}

#Register the DHCP server in AD DSL Add-DhcpServerInDC -DnsName wds1.iammred.net -IPAddress 192.168.0.152

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Moving JSON to the 'processed' folder..."
$FileToMove = Get-Item $DHCPFile
Move-Item -Path $FileToMove -Destination .\~Processed-JSON-Files -Force

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Your DHCP server has been successfully configured!!!"
if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "DHCP Server Deployed!!!" -body $EmailBody }
