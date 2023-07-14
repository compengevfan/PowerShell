$destinations = @(
    "jax-pc002.evorigin.com"
) | Sort-Object

foreach ($destination in $destinations) {
    Write-Host "Processing $destination"
    Invoke-Command -ComputerName $destination -ScriptBlock {
        #Check if NuGet Package Provider is in place
        $NuGetPPCheck = Get-PackageProvider NuGet
        if ($null -eq $NuGetPPCheck) {
            Write-Host "Installing NuGet Package Provider"
            Install-PackageProvider -Name NuGet -Scope CurrentUser -Force
            Import-PackageProvider NuGet
        }
        else {
            Write-Host "NuGet Package Provider already in place."
        }

        #Check if PowerShell Gallery Repository is set as trusted.
        $PsgInstallPolicy = Get-PSRepository -Name PSGallery
        if ($($PsgInstallPolicy.InstallationPolicy) -ne "Trusted") {
            Write-Host "Setting PSGallery Install Policy to Trusted"
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
        else { Write-Host "PSGallery Install Policy already set to Trusted" }
    }
}