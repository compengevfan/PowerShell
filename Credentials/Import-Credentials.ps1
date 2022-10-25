####################
#Import Credentials#
####################

$UserName = $env:USERNAME

if (Test-Path $githome\Credentials\$UserName) {
    $CredFiles = Get-ChildItem $githome\Credentials\$UserName\Cred-*.xml

    foreach ($CredFile in $CredFiles) {
        New-Variable -Name $CredFile.BaseName -Value $(Import-Clixml $CredFile) -Scope Global
    }
    Write-Host "Credentials Imported."
}
else {
    Write-Host "Credential Folder not found. No Creds to import."
}