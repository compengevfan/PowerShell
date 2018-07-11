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

$Selection = Read-Host "Please select the domain to create/override a credential. To exit, enter 'e'"

if ($Selection -le $i)
{
    do
    {
        $Selection -= 1
        $Cred_To_Update = $Domains_In_Array[$Selection].CredName

        if ($Cred_To_Update -eq $null) { Write-Host "Invalid selection. Please try again." -ForegroundColor Red; exit }

        #Obtain credentials. If credential file exists remove it and recreate. If not, create new.
        $Creds = Get-Credential -Message "Please Enter your $Cred_To_Update creds."

        $UserName = $Creds.Username; $UserName = $UserName.Replace("$Cred_To_Update\","")

        if (Test-Path .\"Credential-$UserName-$Cred_To_Update-$ComputerName.xml") { Remove-Item .\"Credential-$UserName-$Cred_To_Update-$ComputerName.xml" }

        $Creds | Export-Clixml -Path ".\Credential-$UserName-$Cred_To_Update-$ComputerName.xml"

        Write-Host "$Cred_To_Update credential created/overwritten." -ForegroundColor Green

        $Selection = Read-Host "Please select the domain to create/override a credential. To create/override all, enter 'a'. To exit, enter 'e'"
    }
    while ($Selection -ne 'e')
}

<#if ($Selection -eq 'a')
{
    Remove-Item .\Credential-$UserName-*.xml

    foreach ($Domain in $Domains)
    {
        $Creds = Get-Credential -Message "Please Enter your $Domain creds."

        $UserName = $Creds.Username; $UserName = $UserName.Replace("$Domain\","")

        $Creds | Export-Clixml -Path ".\Credential-$UserName-$Domain-$ComputerName.xml"
    }
}#>