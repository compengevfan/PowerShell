[CmdletBinding()]
Param(
    [Parameter()] [string] $NameProvided
)

$UserName = $env:USERNAME

if (!(Test-Path .\$UserName)) { New-Item -Name "$UserName" -ItemType Directory | Out-Null }

#Obtain credentials. If credential file exists remove it and recreate. If not, create new.
$Creds = Get-Credential -Message "Please provide your credentials."

if ($NameProvided -eq "" -or $null -eq $NameProvided) { $NameToUse = $Creds.UserName.Replace("\", "_") }
else { $NameToUse = $NameProvided }

if (Test-Path .\$UserName\"Cred-$NameToUse.xml") { Remove-Item .\$UserName\"Cred-$NameToUse.xml" }

$Creds | Export-Clixml -Path ".\$UserName\Cred-$NameToUse.xml"

Write-Host "$NameToUse credential created/overwritten." -ForegroundColor Green