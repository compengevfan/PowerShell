[CmdletBinding()]
Param(
)

#Storage1
#NVMe - NFS
$Storage1_NVMe_Health = (snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.1.1.1.3.4).Replace('"','')
$Storage1_NVMe_AvailableSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.4.4)
$Storage1_NVMe_UsedSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.3.4)
$Storage1_NVMe_UsedPercent = (($Storage1_NVMe_UsedSpace / ($Storage1_NVMe_AvailableSpace + $Storage1_NVMe_UsedSpace)) * 100)

#SSD - NFS
$Storage1_SSD_Health = (snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.1.1.1.3.5).Replace('"','')
$Storage1_SSD_AvailableSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.4.5)
$Storage1_SSD_UsedSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.3.5)
$Storage1_SSD_UsedPercent = (($Storage1_SSD_UsedSpace / ($Storage1_SSD_AvailableSpace + $Storage1_SSD_UsedSpace)) * 100)

#HDD - Storage
$Storage1_HDD_Health = (snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.1.1.1.3.2).Replace('"','')
$Storage1_HDD_AvailableSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.4.2)
$Storage1_HDD_UsedSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.3.2)
$Storage1_HDD_UsedPercent = (($Storage1_HDD_UsedSpace / ($Storage1_HDD_AvailableSpace + $Storage1_HDD_UsedSpace)) * 100)

#HDD2 - Media Backup
$Storage1_HDD2_Health = (snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.1.1.1.3.3).Replace('"','')
$Storage1_HDD2_AvailableSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.4.3)
$Storage1_HDD2_UsedSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.3.3)
$Storage1_HDD2_UsedPercent = (($Storage1_HDD2_UsedSpace / ($Storage1_HDD2_AvailableSpace + $Storage1_HDD2_UsedSpace)) * 100)

$storage1Data = [PSCustomObject]@{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    NVMe = @{
        Health = $Storage1_NVMe_Health
        UsedPercent = [math]::Round($Storage1_NVMe_UsedPercent, 2)
    }
    SSD = @{
        Health = $Storage1_SSD_Health
        UsedPercent = [math]::Round($Storage1_SSD_UsedPercent, 2)
    }
    HDD = @{
        Health = $Storage1_HDD_Health
        UsedPercent = [math]::Round($Storage1_HDD_UsedPercent, 2)
    }
    HDD2 = @{
        Health = $Storage1_HDD2_Health
        UsedPercent = [math]::Round($Storage1_HDD2_UsedPercent, 2)
    }
}

$storage1Data | ConvertTo-Json -Depth 3 | Set-Content -Path "/var/snmp_files/storage1_data.json" -Force

#Storage3
#Volume1 - NFS
$Storage3_Vol1_Health = (snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.4.1).Replace('"','')
$Storage3_Vol1_TotalSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.6.1)
$Storage3_Vol1_FreeSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.7.1)
$Storage3_Vol1_UsedPercent = ((($Storage3_Vol1_TotalSize - $Storage3_Vol1_FreeSize) / $Storage3_Vol1_TotalSize) * 100)

#Volume2 - Storage
$Storage3_Vol2_Health = (snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.4.2).Replace('"','')
$Storage3_Vol2_TotalSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.6.2)
$Storage3_Vol2_FreeSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.7.2)
$Storage3_Vol2_UsedPercent = ((($Storage3_Vol2_TotalSize - $Storage3_Vol2_FreeSize) / $Storage3_Vol2_TotalSize) * 100)

#Volume3 - Media
$Storage3_Vol3_Health = (snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.4.3).Replace('"','')
$Storage3_Vol3_TotalSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.6.3)
$Storage3_Vol3_FreeSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.7.3)
$Storage3_Vol3_UsedPercent = ((($Storage3_Vol3_TotalSize - $Storage3_Vol3_FreeSize) / $Storage3_Vol3_TotalSize) * 100)

$storage3Data = [PSCustomObject]@{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Volume1 = @{
        Health = $Storage3_Vol1_Health
        UsedPercent = [math]::Round($Storage3_Vol1_UsedPercent, 2)
    }
    Volume2 = @{
        Health = $Storage3_Vol2_Health
        UsedPercent = [math]::Round($Storage3_Vol2_UsedPercent, 2)
    }
    Volume3 = @{
        Health = $Storage3_Vol3_Health
        UsedPercent = [math]::Round($Storage3_Vol3_UsedPercent, 2)
    }
}

$storage3Data | ConvertTo-Json -Depth 3 | Set-Content -Path "/var/snmp_files/storage3_data.json" -Force
