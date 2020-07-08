﻿$ComputerName = $env:computername
$UserName = $env:USERDOMAIN + "\" + $env:USERNAME

#Obtain credentials. If credential file exists remove it and recreate. If not, create new.
$Creds = Get-Credential -Message "Please provide your $UserName password." -UserName $UserName

$UserNameFile = $UserName.Replace("\", "_")

if (Test-Path .\"Credential-$UserNameFile-$ComputerName.xml") { Remove-Item .\"Credential-$UserNameFile-$ComputerName.xml" }

$Creds | Export-Clixml -Path ".\Credential-$UserNameFile-$ComputerName.xml"

Write-Host "$UserName credential created/overwritten." -ForegroundColor Green