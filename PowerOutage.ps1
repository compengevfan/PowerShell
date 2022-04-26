[CmdletBinding()]
Param(
)

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
Function Invoke-LoggingPO
{
    Param(
        [Parameter(Mandatory=$true)] [string] $ScriptStarted,
        [Parameter(Mandatory=$true)] [string] $ScriptName,
        [Parameter(Mandatory=$true)][ValidateSet("Succ","Info","Warn","Err")] [string] $LogType,
        [Parameter()] [string] $LogString
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$TimeStamp $LogString" | Out-File .\~Logs\"$ScriptName $ScriptStarted.log" -append

    Write-Host -F DarkGray "[" -NoNewLine
    Write-Host -F Green "*" -NoNewLine
    Write-Host -F DarkGray "] " -NoNewLine
    Switch ($LogType)
    {
        Succ { Write-Host -F Green $LogString }
        Info { Write-Host -F White $LogString }
        Warn { Write-Host -F Yellow $LogString }
        Err { Write-Host -F Red $LogString }
    }
}

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null } else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
  
#Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script Started..."
Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File .\~Logs\PowerOutage-MinuteChecker.txt
"Script Started..." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append

#Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking PC power state..."
"Checking PC power state..." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
$PowerStatusCheck = $(Get-WmiObject win32_battery).BatteryStatus
if ($PowerStatusCheck -eq 2) {
    #Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "PC found to be on utility power. Setting counter to 0 and script exiting."
    "PC found to be on utility power. Setting counter to 0 and script exiting." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
    $i = 0 ; $i | Out-File .\PowerOutage-Data.txt -Force
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
    exit
}

#Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "PC found to be on battery. Checking to see how many times this has been found..."
"PC found to be on battery. Checking to see how many times this has been found..." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
$Content = Get-Content .\PowerOutage-Data.txt
$i = [int]$Content
if ($i -le 2){
    #Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "PC has not been on battery long enough to initiate system shut down. Incrementing counter and script exiting."
    "PC has not been on battery long enough to initiate system shut down. Incrementing counter and script exiting." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
    $i++ ; $i | Out-File .\PowerOutage-Data.txt -Force
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
    exit
}

"Initiating system shut down!!!" | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Initiating system shut down!!!"
Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Connecting to vCenter..."
cvc anthology.evorigin.com

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Disabling vCLS..."
$advName = "config.vcls.clusters.domain-c17.enabled"
$advSetting = Get-AdvancedSetting -Entity $global:DefaultVIServer -Name $advName
Set-AdvancedSetting -AdvancedSetting $advSetting -Value $false -Confirm:$false

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Issuing power down commands for 'kill' VMs..."
$VMs = Get-VM

$WorkGroup = @()
foreach ($VM in $VMs)
{
    $CustomFields = $VM.CustomFields | Select-Object Key, Value
    $CustomField = $CustomFields | Where-Object {$_.Key -eq "Outage"}
    if ($CustomField.Value -eq "Kill")
    {
        $WorkGroup += $VM.Name
    }
}

if ($WorkGroup.count -gt 0)
{
    Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down 'kill' VMs..."
    
    ForEach ($VM in $WorkGroup) {Stop-VM -VM $VM -Confirm:$false}
    
    $NotOffYet = "true"

    while ($NotOffYet -eq "true") 
    {
        start-sleep -s 2
        $NotOffYet = "false"
        ForEach ($VM in $WorkGroup)
        {
            $Check = (Get-VM -Name $VM | Select-Object PowerState)
            if ($Check.PowerState -eq "PoweredOn")
                {
                    $NotOffYet = "true"
                }
        }
        Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "VM kill not complete..."
    }
    Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "VM kill complete."
}

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down remaining VMs except vCenter..."
$VMs = Get-VM | Where-Object {$_.PowerState -eq "PoweredOn" -and $_.Name -ne "anthology"}
Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Issuing VM shutdown commands..."
$VMs | Shutdown-VMGuest -Confirm:$false
Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for all VMs to shutdown..."
$VMCount = $VMs.Count
while ($VMCount -ne 0) {
    Start-Sleep 15
    $VMs = Get-VM | Where-Object {$_.PowerState -eq "PoweredOn" -and $_.Name -ne "anthology" -and $_.Name -notlike "*vCLS*"}
    $VMCount = $VMs.Count
}

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Disconnecting from vCenter..."
Disconnect-VIServer * -Confirm:$false

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down ESX hosts and vCenter..."
$LocalHosts = "esx1.evorigin.com","esx2.evorigin.com","esx3.evorigin.com"
foreach ($LocalHost in $LocalHosts) {
    Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down $LocalHost..."
    Connect-VIServer $LocalHost -Credential ${Credential-ESX-Root-THEOPENDOOR} -Force
    $FindvCenter = Get-VM anthology
    if ($null -ne $FindvCenter -or $FindvCenter -ne "" -and $FindvCenter.PowerState -eq "PoweredOn")
    {
        Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Found vCenter, shutting down..."
        $FindvCenter | Shutdown-VMGuest -Confirm:$false
        while ($FindvCenter.PowerState -eq "PoweredOn")
        {
            Start-Sleep 5
            $FindvCenter = Get-VM anthology
        }
    }
    Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting $LocalHost to MM..."
    Set-VMHost -State Maintenance
    Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Initiating $LocalHost shutdown..."
    Stop-VMHost -Confirm:$false
    Disconnect-VIServer * -Confirm:$false
    while (Test-Connection $LocalHost -Count 1 -Quiet) { start-sleep 5 }
    Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$LocalHost shutdown..."
}

<# $CredUse = ${Credential-ESX-Root-THEOPENDOOR}
Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down ESX hosts and vCenter..."
Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating ESX1 script block..."
$ScriptblockESX1 = {
    $LocalHost = "esx1.evorigin.com"
    Connect-VIServer $LocalHost -Credential $using:CredUse -Force
    $FindvCenter = Get-VM anthology
    if ($FindvCenter -ne $null -or $FindvCenter -ne "")
    {
        $FindvCenter | Shutdown-VMGuest -Confirm:$false
        while ($FindvCenter.PowerState -eq "PoweredOn")
        {
            Start-Sleep 15
            $FindvCenter = Get-VM anthology
        }
    }
    Set-VMHost -State Maintenance
    Stop-VMHost -Confirm:$false
    while (Test-Connection $LocalHost -Count 1 -Quiet) { start-sleep 15 }
}

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating ESX2 script block..."
$ScriptblockESX2 = {
    $LocalHost = "esx2.evorigin.com"
    Connect-VIServer $LocalHost -Credential $using:CredUse -Force
    $FindvCenter = Get-VM anthology
    if ($FindvCenter -ne $null -or $FindvCenter -ne "")
    {
        $FindvCenter | Shutdown-VMGuest -Confirm:$false
        while ($FindvCenter.PowerState -eq "PoweredOn")
        {
            Start-Sleep 15
            $FindvCenter = Get-VM anthology
        }
    }
    Set-VMHost -State Maintenance
    Stop-VMHost -Confirm:$false
    while (Test-Connection $LocalHost -Count 1 -Quiet) { start-sleep 15 }
}

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating ESX3 script block..."
$ScriptblockESX3 = {
    $LocalHost = "esx3.evorigin.com"
    Connect-VIServer $LocalHost -Credential $using:CredUse -Force
    $FindvCenter = Get-VM anthology
    if ($FindvCenter -ne $null -or $FindvCenter -ne "")
    {
        $FindvCenter | Shutdown-VMGuest -Confirm:$false
        while ($FindvCenter.PowerState -eq "PoweredOn")
        {
            Start-Sleep 15
            $FindvCenter = Get-VM anthology
        }
    }
    Set-VMHost -State Maintenance
    Stop-VMHost -Confirm:$false
    while (Test-Connection $LocalHost -Count 1 -Quiet) { start-sleep 15 }
}

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Running ESX1 job..."
Start-Job -Name "ESX1" -ScriptBlock $ScriptblockESX1

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Running ESX2 job..."
Start-Job -Name "ESX2" -ScriptBlock $ScriptblockESX2

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Running ESX3 job..."
Start-Job -Name "ESX3" -ScriptBlock $ScriptblockESX3

$count = (Get-Job | Where-Object { $_.State -like "Running" }).Count
while ($count -gt 0) {
    Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$count jobs still running, waiting for all jobs to complete"
    Get-Job | Where-Object { $_.State -like "Running" } | Select-Object Name
    Start-Sleep 15
    $count = (Get-Job | Where-Object { $_.State -like "Running" }).Count
} #>

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down storage servers..."
Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Sending command to shut down Storage1..."
$Storage1ApiToken = ${Credential-Storage1-API-Token-THEOPENDOOR}.GetNetworkCredential().Password
$headers = @{Authorization = "Bearer $Storage1ApiToken"}
Invoke-RestMethod -Uri "http://Storage1/api/v2.0/system/shutdown" -Method "Post" -Headers $headers | Out-Null

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Sending command to shut down Storage2..."
$Storage2ApiToken = ${Credential-Storage2-API-Token-THEOPENDOOR}.GetNetworkCredential().Password
$headers = @{Authorization = "Bearer $Storage2ApiToken"}
Invoke-RestMethod -Uri "http://Storage2/api/v2.0/system/shutdown" -Method "Post" -Headers $headers | Out-Null

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Sending command to shut down Storage3..."
New-SSHSession -ComputerName Storage3 -Credential ${Credential-Storage3Root-THEOPENDOOR}
Invoke-SSHCommand -SessionId 0 -Command "poweroff"

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down local DC..."
Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Issuing command to shut down DC..."
$VMWWCommand = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$Params = "-T ws stop V:\VMwareVMs\JAX-EVODC003\JAX-EVODC003.vmx"
$Param = $Params.Split(" ")
& "$VMWWCommand" $Param

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Issuing command to shut down local PC..."
$LocalPCCommand = "shutdown"
$Params = "-s -t 30"
$Param = $Params.Split(" ")
& "$LocalPCCommand" $Param

Invoke-LoggingPO -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Script Completed Succesfully."