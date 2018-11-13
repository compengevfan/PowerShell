#——————————————————————————————–#
# Script_Name : DNS_Backup.ps1
# Description : backup all DNS Zones defined on a Windows 2008 DNS Server
# Requirements : Windows 2008/R2 + DNS Management console Installed
# Version : 0.4 - Intergrated comments from Jeffrey Hicks
# Date : October 2011
# Created by Griffon
#——————————————————————————————-#

#– DEFINE VARIABLE——#

# Get Name of the server with env variable

$DNSSERVER=get-content env:fallen

#—Define folder where to store backup  —–#
$BkfFolder=”c:\windows\system32\dns\backup”

#—Define file name where to store Dns Settings
$StrFile=Join-Path $BkfFolder “input.csv”

#—-Check if folder exists. if exists, delete contents–#
if (-not(test-path $BkfFolder)) {
new-item $BkfFolder -Type Directory | Out-Null
} else {

Remove-Item $BkfFolder”\*” -recurse
}

#—- GET DNS SETTINGS USING WMI OBJECT ——–#
#– Line wrapped should be only one line –#
$List = get-WmiObject -ComputerName $DNSSERVER -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone

#—-Export information into input.csv file —#
#– Line wrapped should be only one line –#
$list | Select Name,ZoneType,AllowUpdate,@{Name=”MasterServers”;Expression={$_.MasterServers}},DsIntegrated | Export-csv $strFile -NoTypeInformation

#— Call Dnscmd.exe to export dns zones
$list | foreach {
$path=”backup\”+$_.name
$cmd=”dnscmd {0} /ZoneExport {1} {2}” -f $DNSSERVER,$_.Name,$path
Invoke-Expression $cmd
}

# End of Script
#——————————————————————————————-#