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
        }
        else {
            Write-Host "NuGet Package Provider already in place."
        }
    }
}