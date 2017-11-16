[CmdletBinding()]
Param(
    [Parameter()] [string] $State = "Test",
    [Parameter()] [string] $DoEmails = "No"
)

#This script should run on the PDC of each domain.
#Script assumes that the PDC can properly resolve all Secondary Zones.

#Check to make sure DC is the PDC, if not, send email and halt script.

#1. "DNS-SZ_Check-Fix_SecondaryZones.txt" contains a list of secondary zones that should be on this DNS server. 

#2. Import this file and use it to create the zones if missing. 
    #Script must cycle through all zones in the list.
    #Sript must cycle through all the DNS servers in the domain.
    #If the zone is missing, add it. If the zone exists, ensure the correct masters are in use.
    #If the zone being created is in ff.wh or fanatics.corp, find the DNS servers local to the site to use as masters.
    #If the zone being created is in ff.p10, TBD.

Function SendAnEmail
{
    Param ([Parameter(Mandatory=$True)] [string] $emailserver,
            [Parameter(Mandatory=$True)] [string] $emailTo,
            [Parameter(Mandatory=$True)] [string] $emailFrom,
            [Parameter(Mandatory=$True)] [string] $emailSubject,
            [Parameter(Mandatory=$True)] [string] $emailbody)

    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject $emailSubject -body $emailbody
}

Function DetermineSiteCode
{
    Param ([Parameter(Mandatory=$True)] [string] $IncomingServerName)

    if ($IncomingServerName -like "???-*") { $SiteCode = $IncomingServerName.Substring(0,3) }
    else { $SiteCode = $IncomingServerName.Substring(0,4) }

    return $SiteCode
}

Function DetermineMasterServers
{
    Param ([Parameter(Mandatory=$True)] $RemoteDNSServers,
            [Parameter(Mandatory=$True)] [string] $IncomingSiteCode)

    $MasterServers = @()

    if ($RemoteDNSServers.NameHost -like "*ff.p10") { $MasterServers += "192.168.125.140"; $MasterServers += "192.168.125.141" }
    else
    {
        $FindTheMasters = $RemoteDNSServers | where NameHost -Like "$IncomingSiteCode-*"
        foreach ($FindTheMaster in $FindTheMasters)
        {
            $MasterServers += Resolve-DnsName $FindTheMaster.NameHost | select IPAddress
        }
    }

    return $MasterServers
}

Import-Module ActiveDirectory
Import-Module DnsServer

cd C:\Jobs

#Global Email Variables
$SMTPServer = "smtp.ff.p10"
#$WhoToEmail = "fanatics+IEC@service-now.com"
$WhoToEmail = "cdupree@fanatics.com"
$EmaiIsFrom = "DNS@fanatics.com"

$DomainInfo = Get-ADDomain

$myFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

if ($DomainInfo.PDCEmulator -ne $myFQDN)
{
    $Body = "DNS Name Server script is running on a Domain Controller that is not the PDC.`n`nServer is $myFQDN.`nThis script is designed to run on the PDC."
    if ($DoEmails -eq "Yes") { SendAnEmail -emailserver $SMTPServer -emailTo $WhoToEmail -emailFrom $EmaiIsFrom -emailSubject "Script not executed on PDC!!!" -emailbody $Body }
    else { $Body }

    exit
}

#####################################################
#BEGIN making sure all DNS servers have the correct secondary zones.
#####################################################

#Get a list of all the DNS servers in this domain
$LocalDNSServers = Resolve-DnsName -Name $($DomainInfo.DNSRoot) -Type NS -DnsOnly | Where-Object {$_.NameHost -Like "*$($DomainInfo.DNSRoot)*" -and $_.Section -eq "Answer"} | Select-Object NameHost

#Import secondary zones that should be on this DNS server
$SecondaryZones = Import-Csv .\DNS-SZ_Check-Fix_SecondaryZones.csv

#Cycle through the secondary zones and ensure each DNS server has this zone setup. If zone missing, add. If zone exists, ensure correct masters.
$ChangesMade = $false

$Body = "The following changes have been made to secondary zones in the $($DomainInfo.DNSRoot) domain.`n`n"

foreach ($SecondaryZone in $SecondaryZones)
{
    #Getting a list of DNS servers in the zone to be created. Will be used to find the appropriate master servers.
    $TargetDomainInfo = Get-ADDomainController -Discover -DomainName $($SecondaryZone.owner) -Service PrimaryDC
    $RemoteNameServerList = Resolve-DnsName -Name $($SecondaryZone.owner) -Server $($TargetDomainInfo.Name + "." + $TargetDomainInfo.Domain) -Type NS -DnsOnly | Where-Object {$_.NameHost -Like "*$($TargetDomainInfo.Domain)*" -and $_.Section -eq "Answer"} | Select-Object NameHost

    foreach ($LocalDNSServer in $LocalDNSServers)
    {
        #Check to see if secondary zone exists, if not, create it with the proper master servers.
        $CurrentSiteCode = DetermineSiteCode -IncomingServerName $($LocalDNSServer.NameHost)
        $SecondaryZoneCheck = Get-DnsServerZone -Name $($SecondaryZone.zone) -ComputerName $LocalDNSServer.NameHost -ErrorAction SilentlyContinue
        $MasterServers = DetermineMasterServers -RemoteDNSServers $RemoteNameServerList -IncomingSiteCode $CurrentSiteCode
        if ($SecondaryZoneCheck -eq $null)
        {
            if ($State -eq "Prod") { Add-DnsServerSecondaryZone -Name $SecondaryZone.zone -ZoneFile $($SecondaryZone.zone + ".dns") -ComputerName $($LocalDNSServer.NameHost) -MasterServers $($MasterServers.IPAddress[0]), $($MasterServers.IPAddress[1]) }
            $Body += "$($SecondaryZone.zone) has been added as a secondary zone with $($MasterServers.IPAddress) as the master servers on $($LocalDNSServer.NameHost).`n"
            $ChangesMade = $true
        }
        else
        {
            #If the secondary zone exists, verify that it has the correct master servers. If not, correct it.
            $CurrentMasterServers = $SecondaryZoneCheck.MasterServers | select IPAddressToString | sort IPAddressToString
            $CorrectMasterServers = $MasterServers | sort IPAddress

            if ($($SecondaryZoneCheck.MasterServers.Count) -ne 2 -or $($CurrentMasterServers.IPAddressToString[0]) -ne $($CorrectMasterServers.IPAddress[0]) -or $($CurrentMasterServers.IPAddressToString[1]) -ne $($CorrectMasterServers.IPAddress[1]))
            {
                if ($State -eq "Prod") { Set-DnsServerSecondaryZone -Name $SecondaryZone.zone -ComputerName $($LocalDNSServer.NameHost) -MasterServers $($MasterServers.IPAddress[0]), $($MasterServers.IPAddress[1]) }
                $Body += "$($SecondaryZone.zone) already exists as a secondary zone on $($LocalDNSServer.NameHost). Master servers were incorrect and have been set to $($MasterServers.IPAddress).`n"
                $ChangesMade = $true
            }
            else
            {
                #If the secondary zone exists and the master servers are right, verify that the status of the zone is "running".
                if ($SecondaryZoneCheck.LastZoneTransferResult -ne 0)
                {
                    $TempBody = "$($SecondaryZone.zone) on $($LocalDNSServer.NameHost) is not properly updating!!!"
                    if ($DoEmails -eq "Yes" -and $ChangesMade) { SendAnEmail -emailserver $SMTPServer -emailTo $WhoToEmail -emailFrom $EmaiIsFrom -emailSubject "Secondary Zone Failure!!!" -emailbody $TempBody }
                    if ($DoEmails -ne "Yes" -and $ChangesMade) { $TempBody }
                }
            }
            #Write-Host "$($SecondaryZone.zone) exists on $($LocalDNSServer.NameHost)"
            #Write-Host "Site Code is $CurrentSiteCode"
        }

        Clear-Variable SecondaryZoneCheck
    }
}

if ($DoEmails -eq "Yes" -and $ChangesMade) { SendAnEmail -emailserver $SMTPServer -emailTo $WhoToEmail -emailFrom $EmaiIsFrom -emailSubject "Secondary Zone Updates" -emailbody $Body }
if ($DoEmails -ne "Yes" -and $ChangesMade) { $Body }

#####################################################
#END making sure all DNS servers have the correct secondary zones.
#####################################################