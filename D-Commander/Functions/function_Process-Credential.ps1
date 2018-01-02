Function Process-Credential
{
    Param(
    )

    $UserName = $env:username

    if (!(Test-Path .\Credentials\"Credential-LocalAdminFor-$UserName.xml"))
    {
        $Creds = Get-Credential -Message "You do not have a local admin credential file stored. Please provide the username and password for the local Administrator account."
        Write-Host "Saving credential to the 'Credentials' folder..."
        $Creds | Export-Clixml -Path ".\Credentials\Credential-LocalAdminFor-$UserName.xml"
    }

    New-Variable -Name ImportedCred -Value $(Import-Clixml ".\Credentials\Credential-LocalAdminFor-$UserName.xml")

    return $ImportedCred
}

$LocalCreds = Process-Credential