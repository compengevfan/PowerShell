[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [string] $BrocadeServer
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

function Connect-Brocade
{
    param(
        [Parameter(Mandatory=$true)] [string] $BaseURI,
        $LoginHeader
    )

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Logging in and obtaining session token..."
    try {
        $Login = Invoke-WebRequest -Method Post -Uri $($BaseURI + "/login") -Headers $LoginHeader
        $WSToken = $Login.Headers.WStoken
    }
    catch {
        $String = "Error encountered is:`n`r$($Error[0])`n`rScript executed on $($env:computername). Script exiting!!!"
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString $String
        return 66
    }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Login successful."

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting up logged in header..."
    $ReturnHeader = @{
        'WStoken' = $WSToken
        'Accept' = $AcceptXML
    }
    return $ReturnHeader
}

function Add-Alias
{
    Write-Host "Select Alias Type: `r`n`tA,a = Array`r`n`tS,s = Server"
    $Selection1 = Read-Host "Selection"

    switch ($Selection1) {
        A 
        { 
            $ArrayName = $(Read-Host "Please provide the name of the array (EG: EMC94)").ToUpper()
            $Port = $(Read-Host "Please provide the port identifier (EG: FA3D9 or X1_SC2_FC1)").ToUpper()
            $WWN = $(Read-Host "Please provide the WWN").ToLower()
            
            $AliasName = $ArrayName + "_" + $Port
        }
        S 
        {
            $ServerName = Read-Host "Please provide the name of the server"
            $Port = Read-Host "Please provide the port number"

            $AliasName = $ServerName + "_" + $Port
        }
        Default { "Invalid Selection." }
    }

    $Verification = Read-Host "Alias name will be $AliasName for WWN $WWN. Is that correct (Y/N)"

    if ($Verification -eq "Y")
    {
        [xml]$AliasData = @"
<?xml version="1.0" encoding="UTF-8"?>
<ns3:CreateZoningObjectRequest xmlns:ns2="http://www.brocade.com/networkadvisor/webservices/v1/model" xmlns:ns3="http://www.brocade.com/networkadvisor/webservices/v1/zoneservice/request">
    <ns2:ZoneAlias>
        <zoneAliases>
            <element>
                <memberNames>
                <element>$WWN</element>
                </memberNames>
                <name>$AliasName</name>
            </element>
        </zoneAliases>
    </ns2:ZoneAlias>
</ns3:CreateZoningObjectRequest>
"@

[xml]$ZoneTransaction = @"
<?xml version="1.0" encoding="UTF-8"?>
<ns3:ControlZoneTransactionRequest xmlns:ns3="http://www.brocade.com/networkadvisor/webservices/v1/zoneservice/request">
    <TransactionAction>
        <action>
			<element>START</element>
        </action>
    </TransactionAction>
</ns3:ControlZoneTransactionRequest>
"@

        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking session token..."
        try
        {
            Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics") -Headers $LoggedInHeader | Out-Null
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Session token valid."
        }
        catch
        {
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Session token invalid. Reconnecting..."
            $LoggedInHeader = Connect-Brocade -BaseURI $BaseURI -LoginHeader $LoginHeader
        }

        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Locating WWN..."
        [xml]$FabricsXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics") -Headers $LoggedInHeader).Content
        $Fabrics = $FabricsXML.FcFabricsResponse.fcFabrics
        foreach ($Fabric in $Fabrics)
        {
            if ($null -ne $PortSearch) { Remove-Variable PortSearch }
            [xml]$PortsXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/$($Fabric.name)/fcports") -Headers $LoggedInHeader).Content
            $Ports = $PortsXML.FcPortsResponse.fcPorts
            $PortSearch = $Ports | Where-Object remotePortWwn -eq $WWN
            if ($null -ne $PortSearch) { $FabricKey = $($Fabric.key); $FabricName = $($Fabric.name) }
        }

        if ($null -ne $FabricKey)
        {
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "WWN found on fabric $FabricName"
        }
        else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "WWN not found!!! Please verify WWN and try again." }
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating a zone transaction..."
        Invoke-WebRequest -Method Post -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$FabricKey/controlzonetransaction") -Headers $PostHeader -Body $ZoneTransaction
<#      Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating a alias..."
        Invoke-WebRequest -Method Post -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$FabricKey/createzoningobject") -Headers $PostHeader -Body $AliasData
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Committing a zone transaction..."
        Invoke-WebRequest -Method Post -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$FabricKey/controlzonetransaction") -Headers $PostHeader -Body $ZoneTransaction
#>
        return $LoggedInHeader
    }
}

function Add-Zone
{
    [xml]$ZoneData = @"
<?xml version="1.0" encoding="UTF-8"?>
<root>
   <zones>
      <element>
         <aliasNames>
            <element>$ServerAlias</element>
            <element>$ArrayAlias</element>
         </aliasNames>
         <name>$ServerAlias_$ArrayAlias</name>
         <type>STANDARD</type>
      </element>
   </zones>
</root>
"@

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking session token..."
    try
    {
        Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics") -Headers $LoggedInHeader | Out-Null
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Session token valid."
    }
    catch
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Session token invalid. Reconnecting..."
        $LoggedInHeader = Connect-Brocade -BaseURI $BaseURI -LoginHeader $LoginHeader
    }

    return $LoggedInHeader 
}

###############
#End Functions#
###############

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting header variables..."
$BaseURI = "http://$BrocadeServer/rest"
$AcceptXML = 'application/vnd.brocade.networkadvisor+xml;version=v1'
#$AcceptJSON = 'application/vnd.brocade.networkadvisor+json;version="v1"'
$ContentType = 'application/x-www-form-urlencoded'

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining credentials..."
$Credentials = Get-Credential -Message "Please provide the username and password for connecting to CMCNE"

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting up login header..."
$LoginHeader = @{
    'WSUsername' = $Credentials.username
    'WSPassword' = $Credentials.GetNetworkCredential().password
    'Accept' = $AcceptXML
    'Content-Type' = $ContentType
}

$LoggedInHeader = Connect-Brocade -BaseURI $BaseURI -LoginHeader $LoginHeader; if ($LoggedInHeader -eq 66) {exit}
$PostHeader = @{
	'WStoken' = $LoggedInHeader.WStoken
	'Accept' = $AcceptXML
	'Content-Type' = $AcceptXML
}

while ($true)
{
    Write-Host "Select action: `r`n`t1 = Create alias.`r`n`t2 = Create Zone.`r`n`tQ,q = Quit"
    $Selection = Read-Host "Selection"

    switch ($Selection) {
        1 { $LoggedInHeader = Add-Alias }
        2 { $LoggedInHeader = Add-Zone }
        3 { $LoggedInHeader = Show-Config }
        4 {  }
        5 {  }
        Q { exit }
        Default { "Invalid Selection. Please try again." }
    }
}

<#
[xml]$ResourceGroupsXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups") -Headers $LoggedInHeader).Content
$ResourceGroups = $ResourceGroupsXML.ResourceGroupsResponse.resourceGroups | Where-Object name -ne "All"

[xml]$FabricsXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics") -Headers $LoggedInHeader).Content
$Fabrics = $FabricsXML.FcFabricsResponse.fcFabrics
[xml]$SwitchesXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcswitches") -Headers $LoggedInHeader).Content
$Switches = $SwitchesXML.FcSwitchesResponse.fcSwitches
[xml]$PortsXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcports") -Headers $LoggedInHeader).Content
$Ports = $PortsXML.FcPortsResponse.fcPorts

[xml]$PortsXML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/DEV-FABRIC-B/fcports") -Headers $LoggedInHeader).Content
$Ports = $PortsXML.FcPortsResponse.fcPorts

[xml]$ZoneSW1XML = $(Invoke-WebRequest -Method Get -Uri $($BaseURI + "/resourcegroups/All/fcfabrics/$($Fabrics[0].key)/zones") -Headers $LoggedInHeader).rawContent
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

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting up logout header..."
$LogoutHeader = @{
    WStoken = "WT30BLpw0hRB1WAmtAwsJjazMjA="
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Logging out..."
Invoke-WebRequest -Method Post -Uri $($BaseURI + "/logout") -Headers $LogoutHeader
#>

