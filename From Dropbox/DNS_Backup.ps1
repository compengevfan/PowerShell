#覧覧覧覧覧覧覧覧覧覧覧覧覧覧覧�#
# Script_Name : DNS_Backup.ps1
# Description : backup all DNS Zones defined on a Windows 2008 DNS Server
# Requirements : Windows 2008/R2 + DNS Management console Installed
# Version : 0.4 - Intergrated comments from Jeffrey Hicks
# Date : October 2011
# Created by Griffon
#覧覧覧覧覧覧覧覧覧覧覧覧覧覧覧-#

#� DEFINE VARIABLE覧#

# Get Name of the server with env variable

$DNSSERVER=get-content env:fallen

#優efine folder where to store backup  蘭#
$BkfFolder=把:\windows\system32\dns\backup�

#優efine file name where to store Dns Settings
$StrFile=Join-Path $BkfFolder 妬nput.csv�

#�-Check if folder exists. if exists, delete contents�#
if (-not(test-path $BkfFolder)) {
new-item $BkfFolder -Type Directory | Out-Null
} else {

Remove-Item $BkfFolder能*� -recurse
}

#�- GET DNS SETTINGS USING WMI OBJECT 覧�#
#� Line wrapped should be only one line �#
$List = get-WmiObject -ComputerName $DNSSERVER -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone

#�-Export information into input.csv file �#
#� Line wrapped should be only one line �#
$list | Select Name,ZoneType,AllowUpdate,@{Name=熱asterServers�;Expression={$_.MasterServers}},DsIntegrated | Export-csv $strFile -NoTypeInformation

#� Call Dnscmd.exe to export dns zones
$list | foreach {
$path=巴ackup\�+$_.name
$cmd=播nscmd {0} /ZoneExport {1} {2}� -f $DNSSERVER,$_.Name,$path
Invoke-Expression $cmd
}

# End of Script
#覧覧覧覧覧覧覧覧覧覧覧覧覧覧覧-#