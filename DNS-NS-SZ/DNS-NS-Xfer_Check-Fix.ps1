[CmdletBinding()]
Param(
    [Parameter()] [string] $State = "Test",
    [Parameter()] [string] $DoEmails = "No"
)

#This script should run on the PDC of each domain.
#Script assumes that the PDC can properly resolve all Secondary Zones.

#Check to make sure DC is the PDC, if not, send email and halt script.

#1. "DNS-NS_Check-Fix_XferTarget.txt" contains a list of domains that the AD Integrated zones need to be transferred to.

#2. Import this file and use it to connect these domains and get a list of DNS servers.

#3. Add any missing servers to Name Server list and remove any extra.

#4. "DNS-SZ_Check-Fix_ADI.txt" contains a list of AD Integrated zones that should be transferred.

#5. Import this file and ensure all zones are configured to allow transfers to Name Servers.
    #Script must cycle through all the DNS servers in the domain.

Function SendAnEmail
{
    Param ([Parameter(Mandatory=$True)] [string] $emailserver,
            [Parameter(Mandatory=$True)] [string] $emailTo,
            [Parameter(Mandatory=$True)] [string] $emailFrom,
            [Parameter(Mandatory=$True)] [string] $emailSubject,
            [Parameter(Mandatory=$True)] [string] $emailbody)

    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject $emailSubject -body $emailbody
}

Import-Module ActiveDirectory
Import-Module DnsServer

cd C:\Jobs

#Global Email Variables
$SMTPServer = "smtp.ff.p10"
#$WhoToEmail = "fanatics+IEC@service-now.com"
$WhoToEmail = "cdupree@fanatics.com"
$EmaiIsFrom = "DNS@fanatics.com"

#####################################################
#BEGIN Ensure that the script is running on the PDC. If it's not, exit
#####################################################

$DomainInfo = Get-ADDomain

$LocalDomain = $DomainInfo.DNSRoot

$myFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

if ($DomainInfo.PDCEmulator -ne $myFQDN)
{
    $Body = "DNS Name Server script is running on a Domain Controller that is not the PDC.`n`nServer is $myFQDN.`nThis script is designed to run on the PDC."
    if ($DoEmails -eq "Yes") { SendAnEmail -emailserver $SMTPServer -emailTo $WhoToEmail -emailFrom $EmaiIsFrom -emailSubject "Script not executed on PDC!!!" -emailbody $Body }
    else { $Body }

    exit
}

#####################################################
#END Ensure that the script is running on the PDC. If it's not, exit
#####################################################

#####################################################
#BEGIN verify the local domain has the proper list of remote name servers for all remote domains.
#####################################################

#Get a list of the NS records from the current DNS server. Don't include local.
$LocalNameServerList = Resolve-DnsName -Name $($DomainInfo.DNSRoot) -Type NS -DnsOnly | Where-Object {$_.NameHost -NotLike "*$($DomainInfo.DNSRoot)*" -and $_.Section -eq "Answer"} | Select-Object NameHost

#Write-Host "List of remote name servers on this DNS server"
#$LocalNameServerList

#Obtain a list of all the domains that will need to get zone transfers from this DNS server
$TargetDomains = Get-Content .\DNS-NS-Xfer_Check-Fix_XferTarget.txt

#Go through each remote domain so sync name server lists
foreach ($TargetDomain in $TargetDomains)
{
    #Get domain information for the target
    $TargetDomainInfo = Get-ADDomainController -Discover -DomainName $TargetDomain -Service PrimaryDC -ErrorAction SilentlyContinue

    #Verify that the PDC is able to query the target
    if ($TargetDomainInfo -eq $null)
    {
        $Body = "The PDC, $myFQDN, is unable to query the target domain, $TargetDomain.`nPlease create a method for this PDC to query this domain."
        if ($DoEmails -eq "Yes" -and $ChangesMade) { SendAnEmail -emailserver $SMTPServer -emailTo $WhoToEmail -emailFrom $EmaiIsFrom -emailSubject "PDC cannot query a target domain!!!" -emailbody $body }
        if ($DoEmails -ne "Yes" -and $ChangesMade) { $Body }
    }
    else
    {
        $ChangesMade = $false
        #Get a list of the DNS servers in the remote domain
        $RemoteNameServerList = Resolve-DnsName -Name $TargetDomain -Server $($TargetDomainInfo.Name + "." + $TargetDomainInfo.Domain) -Type NS -DnsOnly | Where-Object {$_.NameHost -Like "*$($TargetDomainInfo.Domain)*" -and $_.Section -eq "Answer"} | Select-Object NameHost

        #Check to make sure that all remote DNS servers are in the list of local Name Servers. If missing, add.
        $Body = "The following NameServers were added to zone $LocalDomain on $myFQDN`n`n"
        foreach ($RemoteNameServer in $RemoteNameServerList.NameHost)
        {
            if ($LocalNameServerList.NameHost -notcontains $RemoteNameServer)
            {
                if ($State -eq "Prod") { Add-DnsServerResourceRecord -NameServer $RemoteNameServer -ZoneName $LocalDomain -Name "." -NS }
                $Body += "$RemoteNameServer`n"
                $ChangesMade = $true
            }
        }

        #Check to make sure that all local Name Servers are in the list of applicable remote Name Servers. If extra, delete.
        $Body += "`nThe following NameServers were removed from zone $LocalDomain on $myFQDN`n`n"
        $LocalNameServerListSubset = $LocalNameServerList | Where-Object {$_.NameHost -Like "*$TargetDomain*"}
        foreach ($LocalNameServer in $LocalNameServerListSubset.NameHost)
        {
            if ($RemoteNameServerList.NameHost -notcontains $LocalNameServer)
            {
                if ($State -eq "Prod") { Remove-DnsServerResourceRecord -ZoneName $LocalDomain -Name "." -RecordData $LocalNameServer -RRType NS -Force }
                $Body += "$LocalNameServer`n"
                $ChangesMade = $true
            }
        }
        if ($DoEmails -eq "Yes" -and $ChangesMade) { SendAnEmail -emailserver $SMTPServer -emailTo $WhoToEmail -emailFrom $EmaiIsFrom -emailSubject "NameServer Updates" -emailbody $Body }
        if ($DoEmails -ne "Yes" -and $ChangesMade) { $Body }
    }

    Clear-Variable TargetDomainInfo
}

#####################################################
#END verify the local domain has the proper list of remote name servers for all remote domains.
#####################################################

#####################################################
#BEGIN making sure ADI zones that need to be transferred are set to allow it.
#####################################################

#Get a list of all the DNS servers in this domain
$LocalDNSServers = Resolve-DnsName -Name $($DomainInfo.DNSRoot) -Type NS -DnsOnly | Where-Object {$_.NameHost -Like "*$($DomainInfo.DNSRoot)*" -and $_.Section -eq "Answer"} | Select-Object NameHost

#Import ADI file 
$ADIDomains = Get-Content .\DNS-NS-Xfer_Check-Fix_ADI.txt

#Cycle through each DNS server and verify that all ADI zones in txt file are set to allow xfer to name servers
$ChangesMade = $false
$Body = "The following is a list of changes made to primary zones on DNS servers in $($DomainInfo.DNSRoot)`n`n"
foreach ($LocalDNSServer in $LocalDNSServers)
{
    foreach ($ADIDomain in $ADIDomains)
    {
        $PrimaryZone = Get-DnsServerZone -Name $ADIDomain -ComputerName $LocalDNSServer.NameHost

        if ($PrimaryZone.SecureSecondaries -ne "TransferToZoneNameServer")
        {
            $ChangesMade = $true
            if ($State -eq "Prod") { Set-DnsServerPrimaryZone -Name $ADIDomain -ComputerName $LocalDNSServer.NameHost -SecureSecondaries "TransferToZoneNameServer" }
            $Body += "Zone $ADIDomain on $($LocalDNSServer.NameHost) has been set to allow zone transfer to Name Servers`n"
        }
    }
}

if ($DoEmails -eq "Yes" -and $ChangesMade) { SendAnEmail -emailserver $SMTPServer -emailTo $WhoToEmail -emailFrom $EmaiIsFrom -emailSubject "Zone Transfer Updates" -emailbody $Body }
if ($DoEmails -ne "Yes" -and $ChangesMade) { $Body }

#####################################################
#END making sure ADI zones that need to be transferred are set to allow it.
#####################################################