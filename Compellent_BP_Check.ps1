[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] $CredFile = $null,
    [Parameter()] [bool] $SendEmail = $false
)
 
$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  
if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "GoAnywhereMonitor@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

$emailFrom = "JAXF-SAN001@fanatics.corp"
$emailTo = "cdupree@fanatics.com"
$emailSubject = "Windows Servers Improperly Configured!!!"
$emailServer = "smtp.ff.p10"
 
#DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType
<#
try { $CurrentJobLog = Get-Content "$GoAnywhereLogs\$($CurrentTime.ToString("yyyy-MM-dd"))\$($ActiveJob.jobNumber).log" }
catch 
{
    $String = "Log file could not be read. The error encountered is:`n`r$($Error[0])`n`rScript executed on $($env:computername)."
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString $String
    if ($SendEmail) { Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "$ScriptName Encountered an Error" -Body $String }
    exit
}
#>

Import-Module "G:\Software\PS_SDK\DellStorage.ApiCommandSet.psd1"

#$ErrorActionPreference = "SilentlyContinue"

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

    $HKEY_Local_Machine = 2147483650    if ($ServerName -like "*ff.p10") { $wmi = Get-Wmiobject -list "StdRegProv" -namespace root\default -Computername $ServerName -Credential $P10Cred }
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

    $HKEY_Local_Machine = 2147483650    $key = "SYSTEM\CurrentControlSet\Control\Class\{4D36E97B-E325-11CE-BFC1-08002BE10318}"    $valuename = "DriverDesc"    $StorageKeys = AccessRegistry -ServerName $ServerName -key $key -ValueType "Key"    #if ($ServerName -like "*ff.p10") { $wmi = Get-Wmiobject -list "StdRegProv" -namespace root\default -Computername $ServerName -Credential $P10Cred }
    #if ($ServerName -like "*fanatics.corp") { $wmi = Get-Wmiobject -list "StdRegProv" -namespace root\default -Computername $ServerName }
    #    ##$wmi = Get-Wmiobject -list "StdRegProv" -namespace root\default -Computername $ServerName -Credential $P10Cred
    #$StorageKeys = $wmi.EnumKey($HKEY_Local_Machine,$key).sNames

    foreach ($StorageKey in ($StorageKeys -like "0*"))
    {
        $TestKey = "SYSTEM\CurrentControlSet\Control\Class\{4D36E97B-E325-11CE-BFC1-08002BE10318}\$StorageKey"
        $value = AccessRegistry -ServerName $ServerName -key $TestKey -valuename $valuename -ValueType "String" #$wmi.GetStringValue($HKEY_Local_Machine,$Testkey,$valuename).sValue

        if($value -like "Microsoft iSCSI*") { $InstanceNumber = $StorageKey }
    }

    return $InstanceNumber
}

###############
#End Functions#
###############

#Import securly stored credentials. P10 domain is using svcShavlik. Fanatics.corp and FF.WH domain is using svcNetwrixAD
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing credential files..."
$P10Cred = Import-Clixml -Path G:\Software\PS_SDK\Credential-JAXF-SAN001-ff.p10.xml
$FanaticsCred = Import-Clixml -Path G:\Software\PS_SDK\Credential-JAXF-SAN001-fanatics.corp.xml
$FFCred = Import-Clixml -Path G:\Software\PS_SDK\Credential-JAXF-SAN001-ff.wh.xml

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing regkey information..."
$RegKeys = Import-Csv G:\Software\PS_SDK\Compellent_BP_Check-data.csv

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting up variables..."
$ProblemsFound = $false
$ServerErrorList = "Attached is a list of servers with incorrect MPIO related registry settings.`nBelow is a list of servers that failed DNS lookup, ping test or WMI call test:`n`n"
$OutputKeyList = @()

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining DSM connection creds..."
$DsmHostName = "localhost"
$DsmUserName = "svcTasks"
$DsmPassword = get-content G:\Software\PS_SDK\cred.txt | convertto-securestringDoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Connecting to DSM..."$Connection = Connect-DellApiConnection -HostName $DsmHostName -User $DsmUserName -Password $DsmPasswordDoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining server list from DSM..."$Servers = Get-DellScServer -Connection $Connection | ? {$_.OperatingSystem -like "*Windows*MPIO" -and $_.Type -eq "Physical" -and $_.Status -eq "Up"} | select ScName,Name,PortType,OperatingSystem | Sort-Object ScName,Nameforeach ($Server in $Servers){    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Begin processing server: $($Server.Name)"    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking to see if connection to server is possible..."    $ConnectionSuccess = $false    if ($Server.Name -like "*ff.p10" -or $Server.Name -like "*fanatics.corp" -or $Server.Name -like "*footballfanatics.wh")    {        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Server name already has a domain. Checking connection..."        $FQDN = $Server.Name        if (!(Test-Connection $FQDN -Count 1)) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Ping to $FQDN failed."; $ServerErrorList += "Ping to $FQDN failed.`n";$ProblemsFound = $true }        else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Ping to $FQDN succeeded."; $ConnectionSuccess = $true }     } else    {        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Server name does not have a domain. Determining domain..."        $Domain = DetermineDomain -ServerName $Server.Name        if ($Domain -eq "DNE") { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Domain look up for $($Server.Name) failed..."; $ServerErrorList +=  "DNS lookup for $($Server.Name) failed.`n";$ProblemsFound = $true }        else         {            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Domain lookup successful. Checking connection..."            $FQDN = $Server.Name + $Domain            if (!(Test-Connection $FQDN -Count 1)) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Ping to $FQDN failed."; $ServerErrorList += "Ping to $FQDN failed.`n";$ProblemsFound = $true }             else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Ping to $FQDN succeeded."; $ConnectionSuccess = $true }        }    }        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Clearing WMI variables..."    $WMISuccess = $false    $WMITest = $null    if ($ConnectionSuccess)    {        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking WMI connection..."        $WMITest = Get-WmiObject Win32_Computersystem -ComputerName $FQDN        if ($WMITest -eq $null) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "WMI call to $FQDN failed..."; $ServerErrorList += "WMI call to $FQDN failed.`n";$ProblemsFound = $true }        else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "WMI call to $FQDN succeeded."; $WMISuccess = $true }    }    if ($ConnectionSuccess -and $WMISuccess)    {        if ($FQDN -like "*ff.p10") { $iSCSICheck = Get-WMIObject Win32_Service -computer $FQDN -credential $P10Cred | where {$_.Name -EQ "MSiSCSI"} }
        if ($FQDN -like "*fanatics.corp") { $iSCSICheck = Get-WMIObject Win32_Service -computer $FQDN -credential $FanaticsCred | where {$_.Name -EQ "MSiSCSI"} }        if ($FQDN -like "*footballfanatics.wh") { $iSCSICheck = Get-WMIObject Win32_Service -computer $FQDN -credential $FFCred | where {$_.Name -EQ "MSiSCSI"} }        if ($($iSCSICheck.State) -eq "Running") { $InstanceNumber = FindISCSI-Instance -ServerName $FQDN }        Write-Host "This server has iSCSI."        foreach ($RegKey in $RegKeys)        {            if (($RegKey.OS -eq "All" -or $Server.OperatingSystem.InstanceName -like "*$($RegKey.OS)*") -and ($RegKey.Fabric -eq "All" -or $RegKey.Fabric -eq $Server.PortType -as [string]))            {                if ($RegKey.Fabric -eq "iSCSI" -and $($iSCSICheck.Status) -eq "Running")                {                    $TempKey = $RegKey.Key.Replace("<Instance Number>", $InstanceNumber)                    $CurrentValue = AccessRegistry -ServerName $FQDN -key $TempKey -valuename $($RegKey.Value) -ValueType "DWORD"                    if ($CurrentValue -ne $($RegKey.CorrectData) -or $CurrentValue -eq $null)
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
                    }                }                                if ($RegKey.Fabric -ne "iSCSI")                 {                    $CurrentValue = AccessRegistry -ServerName $FQDN -key $($RegKey.Key) -valuename $($RegKey.Value) -ValueType "DWORD"                    if ($CurrentValue -ne $($RegKey.CorrectData) -or $CurrentValue -eq $null)
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
                    }                }            }        }    }    Write-Host "End processing server: $($Server.Name)."}if ($ProblemsFound){    $OutputKeyList | Select-Object Compellent, Server, Key, IncorrectValue, CorrectValue | Export-Csv -LiteralPath G:\Software\PS_SDK\RegProblemList.csv -NoTypeInformation    $ServerErrorList += "`n`rScript executed on $($env:computername)."    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Windows Servers Improperly Configured!!!" -body $ServerErrorList -Attachments G:\Software\PS_SDK\RegProblemList.csv    Remove-Item G:\Software\PS_SDK\RegProblemList.csv}