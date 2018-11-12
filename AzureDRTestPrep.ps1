[CmdletBinding()]
Param(
)
 
$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  
#DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType 
<#
try { $CurrentJobLog = Get-Content "$GoAnywhereLogs\$($CurrentTime.ToString("yyyy-MM-dd"))\$($ActiveJob.jobNumber).log" }
catch 
{
    $String = "`n`rError encountered is:`n`r$($Error[0])`n`rScript executed on $($env:computername)."
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString $String
    if ($SendEmail) { Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "$ScriptName Encountered an Error" -Body $String }
    exit
}
#>

if (!(Get-Module -ListAvailable -Name AzureRM)) { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogType "'AzureRM' module not available!!! Script exiting!!!" -ForegroundColor Red; exit }
try { if (!(Get-Module -Name AzureRM)) { Import-Module AzureRM } }
catch { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Azure PowerShell module import failed!!!`n`rError encountered is:`n`r$($Error[0])`n`rScript executed on $($env:computername).`n`rScript Exiting!!!"; exit }

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Connecting to Azure..."
Connect-AzureRMAccount
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting default subscription..."
Select-AzureRmSubscription -Subscription "83d0d0ba-42d5-4c21-a019-3c1b250fbf15"

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing data file..."
$DataFromFile = Import-Csv .\AzureDRTestPrep-Data.csv

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining a list of the ASR Vaults..."
$Vaults = Get-AzureRmRecoveryServicesVault

$RestoreJobs = @()
foreach ($Vault in $Vaults)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Setting vault context..."
    Set-AzureRmRecoveryServicesVaultContext -Vault $Vault
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting backup containers..."
    $Containers = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM

    foreach ($Container in $Containers)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining backup item..."
        $BackupItem = Get-AzureRmRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting latest recovery point..."
        $RecoveryPoints = Get-AzureRmRecoveryServicesBackupRecoveryPoint -Item $BackupItem

        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating restore job for $($Container.FriendlyName)..."
        try
        {
            $RestoreJobs += Restore-AzureRmRecoveryServicesBackupItem -RecoveryPoint $RecoveryPoints[0] -StorageAccountName drtestfanstorage -StorageAccountResourceGroupName DRTEST -TargetResourceGroupName DRTEST -ErrorAction Stop
            #$Details = Get-AzureRmRecoveryServicesBackupJobDetails -Job $RestoreJob
        }
        catch { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Restore job creation failed!!!`n`rError encountered is:`n`r$($Error[0])`n`rScript Exiting!!!"; exit }
    }
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Monitoring for restore job completion..."
do 
{
    $RestoresComplete = $true
    foreach ($RestoreJob in $RestoreJobs)
    {
        Start-Sleep 60
        switch ($(Get-AzureRmRecoveryServicesBackupJob -Job $RestoreJob).Status) 
        {
            "InProgress" { $RestoresComplete = $false }
            "Failed"
            {
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "A Restore Task Failed!!!`n`rError encountered is:`n`r$($Error[0])`n`rScript Exiting!!!"
                exit
            }
            "Cancelled"
            {
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "A Restore Task Was Cancelled!!!`n`rScript Exiting!!!"
                exit
            }
        }
    } 
} while ($RestoresComplete = $false)
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Restore jobs completed."

<#
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
        New-AzureRmVM -ResourceGroupName DRTEST -Location "eastus" -VM $NewVM#>

Write-Host "DR Test VM Deploy Complete!!!"