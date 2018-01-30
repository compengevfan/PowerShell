function Wait-Tools
{
    $Ready = $false
    while (!($Ready))
    {
        $ToolsStatus = (Get-VM -Name $($DataFromFile.VMInfo.VMName)).Guest.ExtensionData.ToolsStatus
        if ($ToolsStatus -eq "toolsOK" -or $ToolsStatus -eq "toolsOld") { $Ready = $true }
        Start-Sleep 5
    }
}