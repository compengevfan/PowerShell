######################
#Connect to a vCenter#
######################

##################
#Check for VMware#
##################
if (!(get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue))
{
    $PrevPath = Get-Location

	write-host ("Adding PowerCLI...")
    if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts")
    {
        cd "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts"
	    .\Initialize-PowerCLIEnvironment.ps1
    }
    if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts")
    {
        cd "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts"
        .\Initialize-PowerCLIEnvironment.ps1
    }

    cd $PrevPath

	write-host ("Complete")
}

$ConnectedvCenter = $global:DefaultVIServers
if ($ConnectedvCenter -ne $null)
{
    $ConnectionResponse = Read-Host "You are already connected to $ConnectedvCenter. Use existing connection? (y/n)"
    if ($ConnectionResponse = "y") { exit }
    else { Disconnect-VIServer -Force -Confirm:$false }
}

$i = 0

if (Test-Path .\ConnectToVcenter-Data.txt)
{
    cls
    $vCenters = Get-Content ConnectToVcenter-Data.txt

    $vCenters_In_Array = @()
    foreach ($vCenter in $vCenters)
    {
        $i++
        $vCenters_In_Array += New-Object -Type PSObject -Property (@{
		Identifyer = $i
        vCenterName = $vCenter
        })
    }

    foreach ($vCenter_In_Array in $vCenters_In_Array)
    {
        Write-Host $("`t`t"+$vCenter_In_Array.Identifyer+".`t"+$vCenter_In_Array.vCenterName)
    }

    $Selection = Read-Host "Please select the vCenter to connect to or enter 'n' to skip."

    if ($Selection -ne "n" -and $Selection -le $i)
    {
        $ii = 0
        $Selection -= 1

        $vCenter_To_Connect = $vCenters_In_Array[$Selection].vCenterName

        $Credentials = GCI .\Credentials\Credential-$ComputerName*.xml

        $Credentials_In_Array = @()
        foreach ($Credential in $Credentials)
        {
            $ii++
            $Credentials_In_Array += New-Object -Type psobject -Property (@{
            Identifyer = $ii
            CredentialName = $Credential.BaseName
            ActualCredential = $Credential
            })
        }

        foreach ($Credential_In_Array in $Credentials_In_Array)
        {
            Write-Host $("`t`t"+$Credential_In_Array.Identifyer+".`t"+$Credential_In_Array.CredentialName)
        }

        $Selection2 = Read-Host "Please select the credential to use or enter 'n' to skip."

        if ($Selection2 -ne "n" -and $Selection2 -le $ii)
        {
            $Selection2 -= 1
            #$Credential_To_Use = #Find Credential
            New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($Credentials_In_Array[$Selection2].ActualCredential))

            Connect-VIServer -Server $vCenter_To_Connect -Credential $Credential_To_Use
        }
    }
} else
{
    Write-Host "vCenter list file does not exist!!!"
}