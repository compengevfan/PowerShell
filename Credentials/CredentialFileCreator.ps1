[CmdletBinding()]
Param(
    [Parameter()] [string] $NameProvided
)

$ComputerName = $env:computername
#$UserName = $env:USERDOMAIN + "\" + $env:USERNAME

#Obtain credentials. If credential file exists remove it and recreate. If not, create new.
$Creds = Get-Credential -Message "Please provide your credentials."# -UserName $UserName

if ($NameProvided -eq "" -or $null -eq $NameProvided) { $NameToUse = $Creds.UserName.Replace("\", "_") }
else { $NameToUse = $NameProvided }

if (Test-Path .\"Credential-$UserNameFile-$ComputerName.xml") { Remove-Item .\"Credential-$UserNameFile-$ComputerName.xml" }

$Creds | Export-Clixml -Path ".\Credential-$NameToUse-$ComputerName.xml"

Write-Host "$($Creds.UserName) credential created/overwritten." -ForegroundColor Green