[CmdletBinding()]
Param(
)
 
$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
#$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
#$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
#if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
#if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
#if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  
#DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType 
<#
try { $CurrentJobLog = Get-Content "$GoAnywhereLogs\$($CurrentTime.ToString("yyyy-MM-dd"))\$($ActiveJob.jobNumber).log" }
catch 
{
    $String = "Error encountered is:`n`r$($Error[0])`n`rScript executed on $($env:computername)."
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString $String
    if ($SendEmail) { Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "$ScriptName Encountered an Error" -Body $String }
    exit
}
#>

if (!(Get-Module -ListAvailable -Name AzureRM)) { Write-Host "'AzureRM' module not available!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name Azure)) { Import-Module AzureRM }

try
{
    $AzureInfo = Get-AzureRmSubscription
    if ($AzureInfo.Id -ne "83d0d0ba-42d5-4c21-a019-3c1b250fbf15") { Write-Host "Azure Connection is incorrect!!!"; exit }
    else { Write-Host "Already Connected to the Correct Azure Subscription..." }
}
catch
{
    Write-Host "Connecting to Azure..."
    Connect-AzureRMAccount
    Select-AzureRmSubscription -Subscription "83d0d0ba-42d5-4c21-a019-3c1b250fbf15"
}

Write-Host "Importing data file..."
$DataFromFile = Import-Csv .\AzureDRTestPrep-Data.csv

Write-Host "Obtaining a list of the ASR Vaults..."
$Vaults = Get-AzureRmRecoveryServicesVault

foreach ($Vault in $Vaults)
{
    Write-Host "Setting vault context..."
    Set-AzureRmRecoveryServicesVaultContext -Vault $Vault
    Write-Host "Getting backup containers..."
    $Containers = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM

    foreach ($Container in $Containers)
    {
        Write-Host "Obtaining backup item..."
        $BackupItem = Get-AzureRmRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM
        Write-Host "Getting latest recovery point..."
        $RecoveryPoints = Get-AzureRmRecoveryServicesBackupRecoveryPoint -Item $BackupItem

        Write-Host "Creating restore job..."
        try
        {
            $RestoreJob = Restore-AzureRmRecoveryServicesBackupItem -RecoveryPoint $RecoveryPoints[0] -StorageAccountName drtestfanstorage -StorageAccountResourceGroupName DRTEST -TargetResourceGroupName DRTEST -ErrorAction SilentlyContinue 
            Write-Host "Waiting for restore job completion..."
            Wait-AzureRmRecoveryServicesBackupJob -Job $RestoreJob
            $RestoreJob = Get-AzureRmRecoveryServicesBackupJob -Job $RestoreJob
            $Details = Get-AzureRmRecoveryServicesBackupJobDetails -Job $RestoreJob
        }
        catch { Write-Host "Error!!!"; exit }

        Write-Host "Creating VM from restored disks..."
        $StorageAccountName = $Details.Properties.'Target Storage Account Name'
        $ContainerName = $Details.Properties.'Config Blob Container Name'
        $ConfigBlobName = $Details.Properties.'Config Blob Name'

        Write-Host "Setting the Azure storage context and restoring the JSON configuration file..."
        Set-AzureRmCurrentStorageAccount -Name $StorageAccountName -ResourceGroupName $($Vault.ResourceGroupName)
        $BlobContent = Get-AzureStorageBlobContent -Container $containerName -Blob $configBlobName -Force
        $obj = ((Get-Content -Path .\$($BlobContent.Name) -Raw -Encoding Unicode)).TrimEnd([char]0x00) | ConvertFrom-Json

        Write-Host "Building VM Configuration and attaching disks..."
        $NewVM = New-AzureRmVMConfig -VMSize $obj.'properties.hardwareProfile'.vmSize -VMName $("$($Container.FriendlyName)" + "-DRT")
        Set-AzureRmVMOSDisk -VM $NewVM -Name "osdisk" -VhdUri $obj.'properties.StorageProfile'.osDisk.vhd.Uri -CreateOption "Attach"
        $NewVM.StorageProfile.OsDisk.OsType = $obj.'properties.StorageProfile'.OsDisk.OsType
        foreach($dd in $obj.'properties.StorageProfile'.DataDisks)
        {
            $NewVM = Add-AzureRmVMDataDisk -VM $NewVM -Name "datadisk1" -VhdUri $dd.vhd.Uri -DiskSizeInGB 127 -Lun $dd.Lun -CreateOption "Attach"
        }

        Write-Host "Setting network information..."
        $vnet = Get-AzureRmVirtualNetwork -Name $($DataFromFile | Where-Object {$_.Server -eq "$($Container.FriendlyName)"}).VNet -ResourceGroupName $($DataFromFile | Where-Object {$_.Server -eq "$($Container.FriendlyName)"}).VNetRG
        $subnetindex=0
        $nic = New-AzureRmNetworkInterface -Name $("$($Container.FriendlyName)" + "-DRTNIC") -ResourceGroupName DRTEST -Location "eastus" -SubnetId $vnet.Subnets[$subnetindex].Id -PrivateIpAddress $($DataFromFile | Where-Object {$_.Server -eq "$($Container.FriendlyName)"}).AzureIP
        $NewVM=Add-AzureRmVMNetworkInterface -VM $NewVM -Id $nic.Id

        Write-Host "Issuing command to build VM..."
        New-AzureRmVM -ResourceGroupName DRTEST -Location "eastus" -VM $NewVM
    }
}
Write-Host "DR Test VM Deploy Complete!!!"