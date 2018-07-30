﻿Import-Module "G:\Software\PS_SDK\DellStorage.ApiCommandSet.psd1"

$ErrorActionPreference = "SilentlyContinue"

###########
#Functions#
###########

Function DetermineDomain
{
    Param ([Parameter(Position=0, Mandatory=$True, ValueFromPipeline=$True)] [string]$ServerName)

    #Write-Verbose "Begin Function 'DetermineDomain'."

	$Domains = @{
		".footballfanatics.wh" = "FF"
		".fanatics.corp" = "FAN"
		".ff.p10" = "P10"
	}

    foreach ($Domain in $Domains.Keys)
    {
        $FQDN = $ServerName + $Domain
        $Check = Test-Connection "$FQDN" -Count 1 -ErrorAction SilentlyContinue

        if ($Check -ne $NULL) { $RetDomain = $Domain }
    }

    #Catch not found
    if ($RetDomain -eq $NULL) { $RetDomain = "DNE" }

    #Write-Verbose "End Function 'DetermineDomain'."

    Return $RetDomain
}

Function AccessRegistry
{
    Param ([Parameter(Mandatory=$True)] [string]$ServerName,
            [Parameter(Mandatory=$True)] [string]$key,
            [Parameter()] [string]$valuename,
            [Parameter()] [string]$ValueType)

    #Write-Verbose "Begin Function 'AccessRegistry'."

    $HKEY_Local_Machine = 2147483650
    if ($ServerName -like "*fanatics.corp") { $wmi = Get-Wmiobject -list "StdRegProv" -namespace root\default -Computername $ServerName -Credential $FanaticsCred}
	if ($ServerName -like "*footballfanatics.wh") { $wmi = Get-Wmiobject -list "StdRegProv" -namespace root\default -Computername $ServerName -Credential $FFCred}

    switch ($ValueType)
    {
        "DWORD" { $value = $wmi.GetDWORDValue($HKEY_Local_Machine,$key,$valuename).uValue }
        "Key" { $value = $wmi.EnumKey($HKEY_Local_Machine,$key).sNames }
        "String" { $value = $wmi.GetStringValue($HKEY_Local_Machine,$key,$valuename).sValue }
    }

    #Write-Verbose "End Function 'AccessRegistry'."

    Return $value
}

Function FindISCSI-Instance
{
    Param ([Parameter(Position=0, Mandatory=$True, ValueFromPipeline=$True)] [string]$ServerName)

    #Write-Verbose "Begin Function 'FindISCSI-Instance'."

    $HKEY_Local_Machine = 2147483650
    #if ($ServerName -like "*fanatics.corp") { $wmi = Get-Wmiobject -list "StdRegProv" -namespace root\default -Computername $ServerName }
    #
    #$StorageKeys = $wmi.EnumKey($HKEY_Local_Machine,$key).sNames

    foreach ($StorageKey in ($StorageKeys -like "0*"))
    {
        $TestKey = "SYSTEM\CurrentControlSet\Control\Class\{4D36E97B-E325-11CE-BFC1-08002BE10318}\$StorageKey"
        $value = AccessRegistry -ServerName $ServerName -key $TestKey -valuename $valuename -ValueType "String" #$wmi.GetStringValue($HKEY_Local_Machine,$Testkey,$valuename).sValue

        if($value -like "Microsoft iSCSI*") { $InstanceNumber = $StorageKey }
    }

    #Write-Verbose "End Function 'FindISCSI-Instance'."

    return $InstanceNumber
}

###############
#End Functions#
###############

#Import securly stored credentials. P10 domain is using svcShavlik. Fanatics.corp and FF.WH domain is using svcNetwrixAD
$P10Cred = Import-Clixml -Path G:\Software\PS_SDK\Credential-JAXF-SAN001-ff.p10.xml
$FanaticsCred = Import-Clixml -Path G:\Software\PS_SDK\Credential-JAXF-SAN001-fanatics.corp.xml
$FFCred = Import-Clixml -Path G:\Software\PS_SDK\Credential-JAXF-SAN001-ff.wh.xml

$RegKeys = Import-Csv G:\Software\PS_SDK\Compellent_BP_Check-data.csv

$ProblemsFound = $false
$ServerErrorList = "Attached is a list of servers with incorrect MPIO related registry settings.`nBelow is a list of servers that failed DNS lookup, ping test or WMI call test:`n`n"
$OutputKeyList = @()

$DsmHostName = "localhost"
$DsmUserName = "svcTasks"
$DsmPassword = get-content G:\Software\PS_SDK\cred.txt | convertto-securestring
        if ($FQDN -like "*fanatics.corp") { $iSCSICheck = Get-WMIObject Win32_Service -computer $FQDN -credential $FanaticsCred | where {$_.Name -EQ "MSiSCSI"} }
                    {
	                    if ($CurrentValue -eq $null) { $CurrentValue = "Value Missing" }

	                    $OutputKeyList += New-Object -Type PSObject -Property (@{
	                    Compellent = $($Server.ScName)
	                    Server = $FQDN
	                    Key = $($RegKey.Key) + "\" + $($RegKey.Value)
	                    IncorrectValue = $CurrentValue
	                    CorrectValue = $($RegKey.CorrectData)
	                    })
	                    $ProblemsFound = $true
                    }
                    {
	                    if ($CurrentValue -eq $null) { $CurrentValue = "Value Missing" }

	                    $OutputKeyList += New-Object -Type PSObject -Property (@{
	                    Compellent = $($Server.ScName)
	                    Server = $FQDN
	                    Key = $($RegKey.Key) + "\" + $($RegKey.Value)
	                    IncorrectValue = $CurrentValue
	                    CorrectValue = $($RegKey.CorrectData)
	                    })
	                    $ProblemsFound = $true
                    }
    $emailFrom = "JAXF-SAN001@fanatics.corp"
    $emailTo = "cdupree@fanatics.com"
    $emailSubject = "Windows Servers Improperly Configured!!!"
    $emailServer = "smtp.ff.p10"