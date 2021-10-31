[CmdletBinding()]
Param(
)

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
Function Invoke-Logging
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

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
  
#Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script Started..."
Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File .\~Logs\PowerOutage-MinuteChecker.txt
"Script Started..." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append

#Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Checking PC power state..."
"Checking PC power state..." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
$PowerStatusCheck = $(Get-WmiObject win32_battery).BatteryStatus
if ($PowerStatusCheck -ne 2) {
    #Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "PC found to be on utility power. Setting counter to 0 and script exiting."
    "PC found to be on utility power. Setting counter to 0 and script exiting." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
    $i = 0 ; $i | Out-File .\PowerOutage-Data.txt -Force
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
    exit
}

#Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Warn -LogString "PC found to be on battery. Checking to see how many times this has been found..."
"PC found to be on battery. Checking to see how many times this has been found..." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
$Content = Get-Content .\PowerOutage-Data.txt
$i = [int]$Content
if ($i -le 2){
    #Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Warn -LogString "PC has not been on battery long enough to initiate system shut down. Incrementing counter and script exiting."
    "PC has not been on battery long enough to initiate system shut down. Incrementing counter and script exiting." | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
    $i++ ; $i | Out-File .\PowerOutage-Data.txt -Force
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File .\~Logs\PowerOutage-MinuteChecker.txt -Append
    exit
}

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Err -LogString "Initiating system shut down!!!"
Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Connecting to vCenter and shutting down all VMs..."
cvc discography.evorigin.com
$VMs = Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}
Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Issuing VM shutdown commands..."
$VMs | Shutdown-VMGuest -Confirm:$false
Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Waiting for all VMs to shutdown..."
$WaitTimer = 0
$VMCount = $VMs.Count
while ($WaitTimer -lt 10 -or $VMCount -ne 0) {
    Start-Sleep 30
    $VMs = Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}
    $VMCount = $VMs.Count
    $WaitTimer++
}

if ($WaitTimer -eq 10){
    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Exited from VM check loop. Looking for any VMs still on and terminating..."
    #Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "There may still be VMs that don't want to turn off..."
    $VMs = Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}
    Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Issuing kill commands..."
    $VMs | Stop-VM $VM -Kill
    Start-Sleep 60
}

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Shutting down ESX hosts..."
$VMHosts = Get-VMHost | Sort-Object Name
foreach ($VMHost in $VMHosts) {
    Set-VMHost -VMhost $VMHost -State Maintenance
    Stop-VMHost
}

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Waiting 2 minutes for ESX hosts to shutdown..."
Start-Sleep 120

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Shutting down storage servers..."
Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Sending command to shut down Storage1..."
$headers = @{Authorization = "Bearer 1-LL1LtA4eQiPXleQvHIyPm10xyE2XTWPHfGEOzoHTdPFCkYUxdfZYM2RRWiCPLnnE"}
Invoke-RestMethod -Uri "http://Storage1/api/v2.0/system/shutdown" -Method "Post" -Headers $headers | Out-Null

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Sending command to shut down Storage2..."
$headers = @{Authorization = "Bearer 1-strmj0XrlTVK4aansrqzBgCKNoapGRH2agkG66LeXHYDhAjxbSUbZq5jjT1X3K7q"}
Invoke-RestMethod -Uri "http://Storage2/api/v2.0/system/shutdown" -Method "Post" -Headers $headers | Out-Null

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Shutting down vCenter and local DC..."
Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Issuing command to shut down vCenter..."
$VMWWCommand = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$Params = "-T ws stop V:\VMwareVMs\discography\discography.vmx"
$Param = $Params.Split(" ")
& "$VMWWCommand" $Param

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Issuing command to shut down DC..."
$VMWWCommand = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$Params = "-T ws stop V:\VMwareVMs\JAX-EVODC003\JAX-EVODC003.vmx"
$Param = $Params.Split(" ")
& "$VMWWCommand" $Param

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Waiting for shut down to complete..."
do {
    Start-Sleep 10
    $vCenter = Test-Connection discography -count 1 -Quiet
    $LocalDC = Test-Connection JAX-EVODC003 -count 1 -Quiet
} while ($vCenter -and $LocalDC)

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName @ScriptName -LogType Info -LogString "Issuing command to shut down local PC..."
$LocalPCCommand = "shutdown"
$Params = "-s -t 30"
$Param = $Params.Split(" ")
& "$LocalPCCommand" $Param

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Script Completed Succesfully."
exit