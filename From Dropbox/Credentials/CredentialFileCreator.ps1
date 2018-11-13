#Credential File Creator

$Domains = Get-Content .\CredentialFileCreator-Data.txt

$Domains_In_Array = @()

$i = 0

$ComputerName = $env:computername

cls

foreach ($Domain in $Domains)
{
    $i++
	$Domains_In_Array += New-Object -Type PSObject -Property (@{
		Identifyer = $i
		CredName = $Domain
	})
}

Write-Host "`nList of available domains:"

foreach ($Domain_In_Array in $Domains_In_Array)
{
	Write-Host $("`t"+$Domain_In_Array.Identifyer+". "+$Domain_In_Array.CredName)
}

$Selection = Read-Host "Please select the domain to create/override a credential. To create/override all, enter 'a'. To exit, enter 'e'"

if ($Selection -ne 'a' -and $Selection -le $i)
{
    do
    {
        $Selection -= 1
        $Cred_To_Update = $Domains_In_Array[$Selection].CredName

        if ($Cred_To_Update -eq $null) { Write-Host "Invalid selection. Please try again." -ForegroundColor Red; exit }

        #Delete a single cred file and replace if exists. If not, create new file.
        if (Test-Path .\"Credential-$ComputerName-$Cred_To_Update.xml") { Remove-Item .\"Credential-$ComputerName-$Cred_To_Update.xml" }

        $Creds = Get-Credential -Message "Please Enter your $Cred_To_Update creds."
        $Creds | Export-Clixml -Path ".\Credential-$ComputerName-$Cred_To_Update.xml"

        Write-Host "$Cred_To_Update credential created/overwritten." -ForegroundColor Green

        $Selection = Read-Host "Please select the domain to create/override a credential. To create/override all, enter 'a'. To exit, enter 'e'"
    }
    while ($Selection -ne 'e')
}

if ($Selection -eq 'a')
{
    Remove-Item .\*.xml

    foreach ($Domain in $Domains)
    {
        $Creds = Get-Credential -Message "Please Enter your $Domain creds."
        $Creds | Export-Clixml -Path ".\Credential-$ComputerName-$Domain.xml"
    }
}