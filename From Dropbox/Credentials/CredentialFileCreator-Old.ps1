#Credential File Creator

Remove-Item .\*.xml

$CredsToCreate = Get-Content .\CredentialFileCreator-Data.txt

$ComputerName = $env:computername

foreach ($CredToCreate in $CredsToCreate)
{
    $Creds = Get-Credential -Message "Please Enter your $CredToCreate creds."
    $Creds | Export-Clixml -Path ".\Creds-$ComputerName-$CredToCreate.xml"
}