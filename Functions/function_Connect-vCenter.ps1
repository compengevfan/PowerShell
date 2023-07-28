function Connect-DFvCenter
{
    Param(
        [Parameter()] [string] $vCenter
    )

    $ConnectedvCenter = $global:DefaultVIServers
    if ($ConnectedvCenter.Count -eq 0)
    {
        if ($vCenter -eq $null -or $vCenter -eq "") { $vCenter = Read-Host "Please provide the name of a vCenter server..." }
        do
        {
            if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) { Write-Host "Attempting to connect to vCenter server $vCenter" }
        
            Connect-VIServer $vCenter | Out-Null
            $ConnectedvCenter = $global:DefaultVIServers

            if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) { Write-Host "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
        } while ($ConnectedvCenter.Count -eq 0)
    }
}