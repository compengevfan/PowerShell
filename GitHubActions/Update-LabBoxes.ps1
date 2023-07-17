$destinations = @(
    "jax-pc002.evorigin.com"
) | Sort-Object

foreach ($destination in $destinations) {
    Write-Host "Processing $destination"
    Invoke-Command -ComputerName $destination CredSSP -ScriptBlock {
        #Check if PowerShell Gallery Repository is set as trusted.
        $PsgInstallPolicy = Get-PSRepository -Name PSGallery
        if ($($PsgInstallPolicy.InstallationPolicy) -ne "Trusted") {
            Write-Host "Setting PSGallery Install Policy to Trusted"
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
        else { Write-Host "PSGallery Install Policy already set to Trusted" }

        #Check if DupreeFunctions Exists. if not, install, if so, update.
        $DfCheck = Get-Module -ListAvailable DupreeFunctions
        if (!($DfCheck)) {
            Write-Host "Installing DupreeFunctions"
            Install-Module DupreeFunctions
        }
        else {
            Write-Host "Updating DupreeFunctions"
            Update-Module DupreeFunctions
        }
    }
}