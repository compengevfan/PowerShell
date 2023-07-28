[CmdletBinding()]
Param(
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
# if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
# if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }

#Check if DupreeFunctions is installed and verify version
if (!(Get-InstalledModule -Name DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion -ErrorAction SilentlyContinue))
{
    try 
    {
        if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Install-Module -Name DupreeFunctions -Scope CurrentUser -Force -ErrorAction Stop }
        else { Update-Module -Name DupreeFunctions -RequiredVersion $DupreeFunctionsMinVersion -Force -ErrorAction Stop }
    }
    catch { Write-Host "Failed to install 'DupreeFunctions' module from PSGallery!!! Error encountered is:`n`r`t$($Error[0])`n`rScript exiting!!!" -ForegroundColor Red ; exit }
}

if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Set URI variables..."
$BaseURI = "https://wiki.csx.com/rest/api/content/"
$PageIndex = "199171460"
$URI = $BaseURI + $PageIndex

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Get API Auth Token..."
$APIToken = ${Credential-Confluence-Dupree-LT550TECY7537X}.GetNetworkCredential().Password

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Get table column headers..."
$DataHeaders = $($(Get-Content C:\temp\AssetReportCombined.csv -First 1).Replace('"', '')).Split(",")

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Get full csv contents..."
$Data = Import-Csv C:\temp\AssetReportCombined.csv

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Get current page version number and increment..."
$Body = @{expand = "version"}
$Header = @{Authorization = "Bearer $APIToken"}
$Results = Invoke-RestMethod -Uri $URI -Method Get -Headers $Header -Body $Body
$Version = $Results.version.number
$NewVersion = $Version += 1

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Start building wiki page table contents by setting up headers..."
$NewContents = '<table class="wrapped fixed-table"><colgroup><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 200.0px;" /><col style="width: 1000.0px;" /></colgroup><tbody><tr>'
foreach ($DataHeader in $DataHeaders) {
    $NewContents += "<th>$DataHeader</th>"
}
$NewContents += "</tr>"

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Add each server record to table contents..."
foreach ($Server in $Data) {
    $NewContents += "<tr><td>$($Server.HostName)</td>"
    $NewContents += "<td>$($Server.Model)</td>"
    $NewContents += "<td>$($Server.ServiceTag)</td>"
    $NewContents += "<td>$($Server.OOW)</td>"
    $NewContents += "<td>$($Server.DaysLeft)</td>"
    $NewContents += "<td>$($Server.PowerStatus)</td>"
    $NewContents += "<td>$($Server.Status)</td>"
    $NewContents += "<td>$($Server.Disposition)</td>"
    $NewContents += "<td>$($Server.Application)</td>"
    $NewContents += "<td>$($Server.OS)</td>"
    $NewContents += "<td>$($Server.OSVersion)</td>"
    $NewContents += "<td>$($Server.Owner)</td>"
    $NewContents += "<td>$($Server.Location)</td>"
    $NewContents += "<td>$($Server.Address)</td>"
    $NewContents += "<td>$($Server.RackLocation)</td>"
    $NewContents += "<td>$($Server.ULocation)</td>"
    $NewContents += "<td>$($Server.NumberOfProcs)</td>"
    $NewContents += "<td>$($Server.CPUModel)</td>"
    $NewContents += "<td>$($Server.Cores)</td>"
    $NewContents += "<td>$($Server.CoresEnabled)</td>"
    $NewContents += "<td>$($Server.NumberOfDIMMs)</td>"
    $NewContents += "<td>$($Server.Memory)</td>"
    $NewContents += "<td>$($Server.DIMMSize)</td>"
    $NewContents += "<td>$($Server.DDRType)</td>"
    $NewContents += "<td>$($Server.Speed)</td>"
    $NewContents += "<td>$($Server.Rank)</td>"
    $NewContents += "<td>$($Server.MemManufacturer)</td>"
    $NewContents += "<td>$($Server.SDCardPresent)</td>"
    $NewContents += "<td>$($Server.DracIP)</td>"
    $NewContents += "<td>$($Server.DracVersion)</td>"
    $NewContents += "<td>$($Server.LCVersion)</td>"
    $NewContents += "<td>$($Server.BIOSVersion)</td>"
    $NewContents += "<td>$($Server.PurchasePrice)</td>"
    $NewContents += "<td>$($Server.Notes)</td></tr>"
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Write end of table contents..."
$NewContents += "</tbody></table>"

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Call rest API put to send data..."
$PutBody = @{"version" = @{"number" = $NewVersion};"title" = "Hardware Inventory API Test";"type" = "page";"body" = @{"storage" = @{"value" = $NewContents;"representation" = "storage"}}}
$PutBodyJSON = $PutBody | ConvertTo-JSON
$Header = @{"Authorization" = "Bearer $APIToken";"Accept" = "application/json";"Content-Type" = "application/json"}
Invoke-RestMethod -Uri $URI -Method Put -Headers $Header -Body $PutBodyJSON
