function Wait-DfShutdown
{
    while ($PowerState -eq "PoweredOn")
    {
        Start-Sleep 5
        $PowerState = (Get-VM $($LocalGoldCopy.Name)).PowerState
    }
}