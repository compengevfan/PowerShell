[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [string] $Server
)

#requires -Version 3.0

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
  
if ($null -ne $CredFile)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}

##################
#Email Variables
##################
#emailTo is a comma separated list of strings eg. "email1","email2"
#$emailFrom = ""
#$emailTo = ""
#$emailServer = ""
 
#Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType 
<#
try
{
    Do-Something
    if (not expected) {Throw "Custom Error"}
}
catch 
{
    if ($Error[0].Exception.tostring() -like "*Custom Error") { "Custom Error Description" }
    else
    {
        $String = "Error encountered is:`n`r$($Error[0])`n`rScript executed on $($env:computername)."
        Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString $String
        if ($SendEmail) { Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "$ScriptName Encountered an Error" -Body $String }
    }
    exit
}
#>

function Connect-Brocade
{
    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Logging in and obtaining session token..."
    try {
        $Login = Invoke-WebRequest -Method Post -Uri $($BaseURI + "/login") -Headers $LoginHeader
        $WSToken = $Login.Headers.WStoken
    }
    catch {
        $String = "Error encountered is:`n`r$($Error[0])`n`rScript executed on $($env:computername). Script exiting!!!"
        Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString $String
        return 66
    }

    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Login successful."

    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting up logged in header..."
    $ReturnHeader = @{
        'WStoken' = $WSToken
        'Accept' = $AcceptXML
    }
    return $ReturnHeader
}

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting header variables..."
$BaseURI = "http://$Server/rest"
$AcceptXML = 'application/vnd.brocade.networkadvisor+xml;version=v1'
$AcceptJSON = 'application/vnd.brocade.networkadvisor+json;version="v1"'
$ContentType = 'application/x-www-form-urlencoded'

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining credentials..."
$Credentials = Get-Credential -Message "Please provide the username and password for connecting to CMCNE"

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting up login header..."
$LoginHeader = @{
    'WSUsername' = $Credentials.username
    'WSPassword' = $Credentials.GetNetworkCredential().password
    'Accept' = $AcceptXML
    'Content-Type' = $ContentType
}

$LoggedInHeader = Connect-Brocade

[xml]$FabricsXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics") -Headers $LoggedInHeader).Content
$Fabrics = $FabricsXML.FcFabricsResponse.fcFabrics
[xml]$SwitchesXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcswitches") -Headers $LoggedInHeader).Content
$Switches = $SwitchesXML.FcSwitchesResponse.fcSwitches
[xml]$PortsXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcports") -Headers $LoggedInHeader).Content
$Ports = $PortsXML.FcPortsResponse.fcPorts

[xml]$ZoneSW1XML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$($Fabrics[0].key)/zones") -Headers $LoggedInHeader).Content
$ZoneSW1 = $ZoneSW1XML.ZonesResponse.zones
[xml]$ZoneSW2XML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$($Fabrics[1].key)/zones") -Headers $LoggedInHeader).Content
$ZoneSW2 = $ZoneSW2XML.ZonesResponse.zones

[xml]$ZoneSetsSW1XML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$($Fabrics[0].key)/zonesets") -Headers $LoggedInHeader).Content
$ZoneSetsSW1 = $ZoneSetsSW1XML.ZoneSetsResponse.zonesets
[xml]$ZoneSetsSW2XML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$($Fabrics[1].key)/zonesets") -Headers $LoggedInHeader).Content
$ZoneSetsSW2 = $ZoneSetsSW1XML.ZoneSetsResponse.zonesets

[xml]$ZoneAliasesSW1XML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$($Fabrics[0].key)/zonealiases") -Headers $LoggedInHeader).Content
$ZoneAliasesSW1 = $ZoneAliasesSW1XML.ZoneAliasesResponse.zoneAliases
[xml]$ZoneAliasesSW2XML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$($Fabrics[1].key)/zonealiases") -Headers $LoggedInHeader).Content
$ZoneAliasesSW2 = $ZoneAliasesSW1XML.ZoneAliasesResponse.zoneAliases

[xml]$data = @"
<?xml version="1.0" encoding="UTF-8"?>
<root>
   <zoneAliases>
      <element>
         <memberNames>
            <element>11:22:33:44:55:66:77:88</element>
         </memberNames>
         <name>host_hba0</name>
      </element>
      <element>
         <memberNames>
            <element>88:77:66:55:44:33:22:11</element>
         </memberNames>
         <name>array_sp0</name>
      </element>
   </zoneAliases>
   <zones>
      <element>
         <aliasNames>
            <element>host_hba0</element>
            <element>array_sp0</element>
         </aliasNames>
         <name>host1_hba0_array_sp0</name>
         <type>STANDARD</type>
      </element>
   </zones>
</root>
"@
<#
Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting up logout header..."
$LogoutHeader = @{
    WStoken = $WSToken
}

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Logging out..."
Invoke-WebRequest -Method Post -Uri $($BaseURI + "/logout") -Headers $LogoutHeader
#>
#>