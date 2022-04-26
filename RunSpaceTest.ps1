$Cred = ${Credential-ESX-Root-THEOPENDOOR}
$Scriptblock = {
    Connect-VIServer esx2.evorigin.com -Credential $using:Cred -Force
    $VM = Get-VM JAX-OCLI001
    Stop-VM -VM $VM -Confirm:$false
}
Start-Job -Name "Test" -ScriptBlock $Scriptblock

Get-Job | Receive-Job

Remove-Job -Id 1

$Runspace = [runspacefactory]::CreateRunspace()
$Powershell = [powershell]::Create()
$Powershell.runspace = $Runspace
$Runspace.Open()
$Powershell.AddScript($Scriptblock)
$Job = $Powershell.BeginInvoke()

$Job

foreach ($task in $tasks) {
    $i++
    Write-Progress -Activity "Running Reporting Tasks" -Status ("Current Task: {0}" -f $task) -PercentComplete ($i / $tasks.count * 100)
    Write-Host "Calling $task"
    while ((Get-Job | where { $_.State -like "Running" }).Count -ge $throttle) {
        Write-Host "Throttle set to $throttle jobs.  Waiting to start more" -foregroundcolor "Yellow"
        Get-Job | where { $_.State -like "Running" } | Select-Object Name
        Start-Sleep 60
    }
    Start-Job -Name "Body_$($task)" -ScriptBlock {
        . $(($using:path) + "\Send-VMware_Report_Functions.ps1")
        . Connect-VC | Out-Null
        Disconnect-VIServer vc-tjaxl -Confirm:$false
        Disconnect-VIServer vc-cjaxt -Confirm:$false
        & $using:task
        . Disconnect-VC
    } | Out-Null
}