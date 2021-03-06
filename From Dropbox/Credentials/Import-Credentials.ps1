﻿####################
#Import Credentials#
####################

cls

Remove-Variable Credential-*

$ComputerName = $env:computername

$CredFiles = GCI .\Credential-$ComputerName*.xml

if($CredFiles)
{
    Write-Host "Cred Files Found..."
    Write-Host "To use existing files, press 'enter'."
    $CredAnswer = Read-Host "To create new files, enter 'c'"
}

if ($CredAnswer -eq 'c' -or !($CredFiles))
{
    .\CredentialFileCreator-V2.ps1
    $CredFiles = GCI .\Credential-$ComputerName*.xml
}

if ($CredFiles.Count -gt 0)
{
    foreach ($CredFile in $CredFiles)
    {
        New-Variable -Name $($CredFile.BaseName) -Value $(Import-Clixml $CredFile.Name)
    }
    
	Write-Host "Creds Imported."
} else
{
    Write-Host "No cred files exist!!!"
}