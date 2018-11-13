Function RetrieveAllDomainServers{
    Param ([Parameter(Position=0, Mandatory=$True, ValueFromPipeline=$True)] [string]$RequestedDomain)

    switch ($RequestedDomain){
        "FF" {$ServerList = Get-ADComputer -Filter "OperatingSystem -like '*Windows*'" -Server "JXFC-DC003.footballfanatics.wh" -Property Name,OperatingSystem | Where {$_.DistinguishedName -notlike "*OU=Disabled Computers,dc=footballfanatics,dc=wh"} | Sort-Object Name}
        "FAN" {$ServerList = Get-ADComputer -Filter "OperatingSystem -like '*Windows*'" -Server "JXFC-DC001.FANATICS.CORP" -Property Name,OperatingSystem | Where {$_.DistinguishedName -notlike "*OU=Disabled Computers,dc=fanatics,dc=corp"} | Sort-Object Name}
        "OP10" {$ServerList = Get-ADComputer -Filter "Name -like 'ORD*' -and OperatingSystem -like '*Windows*'" -Server "ord-dc002.ff.p10" -Property Name,OperatingSystem | Where {$_.DistinguishedName -notlike "*OU=Disabled Computers,dc=ff,dc=p10"} | Sort-Object Name}
        "JP10" {$ServerList = Get-ADComputer -Filter "Name -notlike 'ORD*' -and OperatingSystem -like '*Windows*'" -Server "jax-dc001.ff.p10" -Property Name,OperatingSystem | Where {$_.DistinguishedName -notlike "*OU=Disabled Computers,dc=ff,dc=p10"} | Sort-Object Name}
        "EVO" {$ServerList = Get-ADComputer -Filter "OperatingSystem -like '*Windows*'" -Property Name,OperatingSystem| Sort-Object Name}
        default {write-host "Domain is not valid. Please enter 'FF', 'FAN', 'OP10', or 'JP10'."}
    }

    Return $ServerList
}