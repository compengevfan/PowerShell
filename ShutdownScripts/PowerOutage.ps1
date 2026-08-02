[CmdletBinding()]
Param()

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath

$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null } else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script Started..."

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing Credentials..."
Import-DfCredentials

$ProxmoxToken = $CredProxmoxToken.GetNetworkCredential().Password
$ProxmoxNodes = @("pmx1.evorigin.com", "pmx2.evorigin.com", "pmx3.evorigin.com")

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down all VMs on Proxmox nodes..."
foreach ($Node in $ProxmoxNodes) {
    $NodeShortName = $Node.Split(".")[0]
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting running VMs on $NodeShortName..."
    $VMs = (Invoke-DfProxmoxRequest -ProxmoxServer $Node -ProxmoxToken $ProxmoxToken -Method Get -Endpoint "/api2/json/nodes/$NodeShortName/qemu").data |
        Where-Object { $_.status -eq "running" }

    if ($VMs.Count -gt 0) {
        foreach ($VM in $VMs) {
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down VM $($VM.name) (VMID $($VM.vmid)) on $NodeShortName..."
            Invoke-DfProxmoxRequest -ProxmoxServer $Node -ProxmoxToken $ProxmoxToken -Method Post -Endpoint "/api2/json/nodes/$NodeShortName/qemu/$($VM.vmid)/status/shutdown" | Out-Null
        }

        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for all VMs on $NodeShortName to stop..."
        $Running = $true
        while ($Running) {
            Start-Sleep 10
            $RunningVMs = (Invoke-DfProxmoxRequest -ProxmoxServer $Node -ProxmoxToken $ProxmoxToken -Method Get -Endpoint "/api2/json/nodes/$NodeShortName/qemu").data |
                Where-Object { $_.status -eq "running" }
            $Running = $RunningVMs.Count -gt 0
            if ($Running) {
                Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "$($RunningVMs.Count) VM(s) still running on $NodeShortName..."
            }
        }
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "All VMs on $NodeShortName stopped."
    }
    else {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "No running VMs found on $NodeShortName."
    }
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down Proxmox nodes..."
foreach ($Node in $ProxmoxNodes) {
    $NodeShortName = $Node.Split(".")[0]
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Sending shutdown command to $NodeShortName..."
    Invoke-DfProxmoxRequest -ProxmoxServer $Node -ProxmoxToken $ProxmoxToken -Method Post -Endpoint "/api2/json/nodes/$NodeShortName/status" -Body @{ command = "shutdown" } | Out-Null
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for $NodeShortName to go offline..."
    while (Test-Connection $Node -Count 1 -Quiet) { Start-Sleep 5 }
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$NodeShortName is offline."
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Sending shutdown command to Storage1..."
$Storage1ApiToken = $CredStorage1ApiToken.GetNetworkCredential().Password
$headers = @{ Authorization = "Bearer $Storage1ApiToken" }
Invoke-RestMethod -Uri "http://Storage1/api/v2.0/system/shutdown" -Method "Post" -Headers $headers | Out-Null

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Sending shutdown command to Storage3..."
New-SSHSession -ComputerName Storage3 -Credential $CredStorage3Root
Invoke-SSHCommand -SessionId 0 -Command "poweroff"

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Script Completed Successfully."
