<#
Script: Expand-VM_OsDrive.ps1
Author: Joe Titra
Version: 0.1
Description: Expands OS drive up to maximum allowed size.
.EXAMPLE
  PS> .\Expand-VM_OsDrive -Server <server>
#>
[cmdletbinding()]
Param (
    $Server,
    $addGB = 5,
    $maxDriveSize = 80,
    [switch]$Multi
)

function expandDrive($expandVmDrive){
    Copy-VMGuestFile -Source ($env:TEMP + "\winExpansion.txt") -Destination "C:\Temp" -LocalToGuest -VM $vm -GuestCredential $cred -Force
    Start-Sleep 2
    if($expandVmDrive){
        Set-HardDisk -HardDisk $vmDrive -CapacityGB $extendedCapacity -Confirm:$false
    }
    $scriptOutput = Invoke-VMScript -ScriptText $script -VM $vm -GuestCredential $cred -ScriptType Bat
    if($scriptOutput.ScriptOutput -match "successfully"){
        Write-Host "DiskPart successfully extended the volume." -ForegroundColor "Green"
    }
    else{
        Write-Host "Drive expansion was not successful" -ForegroundColor "Red"
        sendErrorEmail
        break
    }
}

function sendErrorEmail{
    Write-Host "not implemented yet.."
    Write-Host "will eventually email something..."
}

if(!($Server)){
    Write-Host "Must provide VM" -ForegroundColor "Red"
    $Server = Read-Host "Enter VM that needs it's OS drive extended"
}

if(!($cred)){
    if($env:USERNAME -eq 'z_vmware'){
        if($env:COMPUTERNAME -eq 'TJAXP80400APP'){ #worker-vcms-mgmt
            $cred = Import-CliXml ($env:githome + "\powershell\etc\cred\zvmware-worker_vcms_mgmt.xml")
        }
    }
    else{
        if($env:USERNAME -match "-admin"){
            $userName = ("$env:USERDOMAIN"+"\"+"$env:USERNAME")
        }
        else{
            $userName = ("$env:USERDOMAIN"+"\"+"$env:USERNAME"+"-admin")
        }
        $global:cred = Get-Credential -UserName $userName -Message "Enter AD credentials with Admin access to server: $Server"
    }
}

$winExpansion = (
    "rescan",
    "select disk 0",
    "select partition 1",
    "extend"
)
<#
$linExpansion = (
    "TBD"
)
#>

$winExpansion | Out-File ($env:TEMP + "\winExpansion.txt") -Encoding ascii
$script = '%SystemRoot%\system32\diskpart.exe /s C:\Temp\winExpansion.txt'

if(!($global:expandDriveRuns)){
    Connect-VC
    $global:expandDriveRuns = 1
}
if(!($global:DefaultVIServer)){
    Write-Host "Must be connected to a vCenter!" -ForegroundColor "Red"
    break
}
#Check for VM
try{
    $vm = Get-VM $Server -ErrorAction Stop
    Write-Host "Found server: $($vm.Name) in cluster $($vm.VMHost.Parent.Name)" -ForegroundColor "Green"
}
catch [Exception]{
    Write-Host "VM with name: $Server not found!" -ForegroundColor "Red"
    sendErrorEmail
    break
}
#Check for snapshots
if((Get-VM $vm | Get-Snapshot) -ne $null){
    Write-Host "Snapshot found on VM: $vm" -ForegroundColor "Red"
    Write-Host "Cannot continue until snapshot is removed" -ForegroundColor "Red"
    sendErrorEmail
    break
}
#Get OS drive
$scsiController = (Get-ScsiController -VM $vm) | sort @{E={$_.ExtensionData.Key}} | select -First 1
$vmDrive = Get-HardDisk -VM $vm | where{$_.ExtensionData.ControllerKey -eq $scsiController.ExtensionData.Key} | sort @{E={$_.ExtensionData.Key}} | select -First 1
$osDrive = Get-WmiObject -Class WIN32_LogicalDisk -ComputerName $vm.Name -Credential $cred | where{$_.DeviceID -eq "C:"} -ErrorAction Stop
if($osDrive -eq $null){
    Write-Host "Could not authenticate to server: $Server" -ForegroundColor "Red"
    sendErrorEmail
    break
}
#Compare drive sizes
$originalSize = [math]::Round($osDrive.Size/1GB,0)
if($vmDrive.CapacityGB -gt $originalSize){
    Write-Host "VM already has additional capacity added. Attempting to expand drive in OS." -ForegroundColor "Yellow"
    expandDrive $false
    $extendedCapacity = $vmDrive.CapacityGB
}
else{
    #Check if drive is already at max size
    $extendedCapacity = $vmDrive.CapacityGB + $addGB
    if($extendedCapacity -gt $maxDriveSize){
        if($vmDrive.CapacityGB -ge $maxDriveSize){
            Write-Host "Drive is already the largest allowed by auto expansion process." -ForegroundColor "Red"
            sendErrorEmail
            break
        }
        else{
            Write-Host "Drive is $($vmDrive.CapacityGB) GB and will only be expanded to $maxDriveSize The largest allowed by auto expansion process." -ForegroundColor "Yellow"
            $extendedCapacity = $maxDriveSize
        }
    }
    #Validate datastore space
    $datastore = $vmDrive | Get-Datastore
    $percFree = ([math]::Round((($datastore.FreeSpaceGB - $addGB) / ([long]$datastore.CapacityGB) * 100),0))
    if($percFree -gt 5){
        Write-Host "Datastore will have $percFree % free space remaining after expansion." -ForegroundColor "Green"
    }
    else{
        Write-Host "Datastore will have less than 5 % free space remaining after expansion. Cannnot continue." -ForegroundColor "Red"
        break
    }
    #Expand drive
    expandDrive $true
}
#Validate drive size
$osDriveAfter = Get-WmiObject -Class WIN32_LogicalDisk -ComputerName $vm.Name -Credential $cred | where{$_.DeviceID -eq "C:"}
$finalSize = [math]::Round($osDriveAfter.Size/1GB,0)
if(($finalSize -gt $originalSize) -and ($extendedCapacity -eq $finalSize)){
    Write-Host "Drive was extended to the requested size: $extendedCapacity GB" -ForegroundColor "Green"
}
else{
    Write-Host "Drive expansion was not successful" -ForegroundColor "Red"
    Write-Host "DEBUG: Final Size: $finalSize should be greater than Original Size: $originalSize" -ForegroundColor "Yellow"
    Write-Host "DEBUG: Extended Capacity: $extendedCapacity should equal Final Size: $finalSize"  -ForegroundColor "Yellow"
    sendErrorEmail
    break
}
if(!($Multi)){
    Disconnect-VC
    Remove-Variable DefaultVIServers -Scope global
    Remove-Variable expandDriveRuns -Scope global
}