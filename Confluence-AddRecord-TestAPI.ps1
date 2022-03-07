[CmdletBinding()]
Param(
)

$BaseURI = "https://wiki.csx.com/rest/api/content/"
$PageIndex = "199167099"
$URI = $BaseURI + $PageIndex

$Date = Get-Date -Format "MM/dd/yyyy"

$APIToken = ${Credential-Confluence-Dupree-LT550TECY7537X}.GetNetworkCredential().Password

$Data = Import-Csv .\Confluence-AddRecord-2021StorageAllocationSRs-Data.csv

$Workflow = $Data[0].Data
$Project = $Data[1].Data
$Array = $Data[2].Data
$Serial = $Data[3].Data
$Server = $Data[4].Data
$Given = $Data[5].Data
$Returned = $Data[6].Data
$Replicated = $Data[7].Data
$Admin = $Data[8].Data
$Type = $Data[9].Data
$Note = $Data[10].Data

$Body = @{expand = "body.storage,version"}
$Header = @{Authorization = "Bearer $APIToken"}
$Results = Invoke-RestMethod -Uri $URI -Method Get -Headers $Header -Body $Body

$Version = $Results.version.number
$TableContents = $Results.body.storage.value

$NewVersion = $Version += 1
$NewContents = $TableContents.Replace("</tbody></table>", "<tr><td>$Date</td><td>$Workflow</td><td>$Project</td><td>$Array</td><td>$Serial</td><td>$Server</td><td>$Given</td><td>$Returned</td><td>$Replicated</td><td>$Admin</td><td>$Type</td><td>$Note</td></tr></tbody></table>")

$PutBody = @{"version" = @{"number" = $NewVersion};"title" = "2021 Storage Allocation SRs";"type" = "page";"body" = @{"storage" = @{"value" = $NewContents;"representation" = "storage"}}}
$PutBodyJSON = $PutBody | ConvertTo-JSON
$Header = @{"Authorization" = "Bearer $APIToken";"Accept" = "application/json";"Content-Type" = "application/json"}
Invoke-RestMethod -Uri $URI -Method Put -Headers $Header -Body $PutBodyJSON
