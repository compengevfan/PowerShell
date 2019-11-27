<#
Script: Set-VM_SRM.ps1
Author: Lord Imson
Version: 0.1
Description: Migrates VM to RDFG and Configures the Protection Group

.EXAMPLE
  PS> .\Set-VM_SRM.ps1 h:\vmsRdfg01.txt
#>
[cmdletbinding()]
Param (
    [Parameter(Mandatory=$True)]$file,
    $ErrorActionPreference = "Stop"
)
$vms = Get-Content $file
$viServer = "vc-tjaxp"
$creds = Get-Credential -Message "Enter Credentials for VC/SRM"

Connect-VIServer $viServer -Credential $creds
Connect-SrmServer -Credential $creds -RemoteCredential $creds

if(-not((Get-Module).Name -match "Meadowcroft.Srm")){
   Import-Module \\appshare\techvirt\VMware_ESX\VMware_SRM\SRM-Cmdlets-master\Meadowcroft.Srm.psd1
}

function disconnectExit {
    Disconnect-VIServer * -Confirm:$false
    Disconnect-SrmServer * -Confirm:$false
    exit
}

#Determine which RDFG Datastore to sVMx the vm to
$vmsDSInfo = @()
foreach($vm in $vms){
    Write-Host Determining datastore pair for $vm
    $vmDSInfo = @()
    $vmDS     = Get-VM $vm | Get-Datastore
        
    if($vmDS -match "RDFG"){
        Read-Host $vm "is already in an RDFG Datastore, Please remove from the list - Exiting"
        disconnectExit
    }elseif($vmDS -match "tjaxp01"){
        $vmRDFG = 'RDFG87'
    }elseif($vmDS -match "tjaxp02"){
        $vmRDFG = 'RDFG88'
    }elseif($vmDS -match "tjaxp03"){
        $vmRDFG = 'RDFG85'
    }elseif($vmDS -match "tjaxp70"){
        $vmRDFG = 'RDFG89'
    }else{
        Read-Host "Invalid Datastore - Exiting"
        disconnectExit
    }
    $vmDSInfo += New-Object psobject -Property ([ordered]@{
                "Name"       = $vm
                "Datastore"  = $vmDS
                "RDFG"       = $vmRDFG
            })

    $vmsDSInfo += $vmDSInfo
}

Write-Host "Email DASDMGT to put the following Datastores in Adaptive Copy Mode and WAIT for confirmation before continuing" -ForegroundColor Green
Write-Host ($vmsDSInfo.RDFG | select -Unique) -ForegroundColor Green 
Write-Host ""
Write-Host "Type srmGO to continue" -ForegroundColor Green
$response = Read-Host 
    if( $response -cne "srmGO" ){ disconnectExit }

#Begin sVMx
$sVmotionLimit = 5
$i=0
foreach($vm in $vmsDSInfo){
    $i++
    $pending = $vmsDSInfo.count -$i
    Write-Progress -Activity "Migrating Datastores to RDFG" -Status "$pending VMs Remaining (insert elevator music here)" -PercentComplete ($i/$vmsDSInfo.Count*100) -Id 0
    $tasks = Get-Task -Status Running | where{$_.Name -like "*RelocateVM_Task*"}
   
    [string]$vmHost = (Get-vm $vm.Name | select -ExpandProperty VMHost)
    $vmSpaceNeeded  = (Get-HardDisk -VM $vm.Name | measure -sum CapacityGB).sum
    $rdfgDs         = Get-Cluster ($vmhost.Substring(0,7)) | Get-Datastore |?{$_.name -match $vm.RDFG} | Sort-Object FreeSpaceGB -Descending | select -First 1
    $rdfgDsFree     = $rdfgDs | Select -ExpandProperty FreeSpaceGB

        if($tasks.Count -lt $sVmotionLimit){
            Write-Host $vm.Name "with" $vmSpaceNeeded "GB needed, will move to" $rdfgDs "which has" $rdfgDsFree "GB remaining" -ForegroundColor Green
           
               if($rdfgDsFree -lt ($vmSpaceNeeded + 100)){
                    Write-Host "RDFG" $rdfgDs "will have less than 100GB after the move, please request for more storage" -ForegroundColor Red
                    Read-Host -prompt "Continue? or ctrl-C to Quit"
                }           
                    Get-VM $vm.Name | Move-VM -Datastore $rdfgDs -DiskStorageFormat Thin -RunAsync
        }else{
            while($tasks.Count -ge $sVmotionLimit) {
                Write-Host Storage vMotions are limited to $sVmotionLimit Please Wait... -Foreground Yellow
                Start-Sleep -Seconds 30
                $tasks = Get-Task -status Running | ?{$_.name -like "*RelocateVM_Task*"}
            }
                Write-Host $vm.Name "with" $vmSpaceNeeded "GB needed, will move to" $rdfgDs "which has" $rdfgDsFree "GB remaining" -ForegroundColor Green
                                
                    if($rdfgDsFree -lt ($vmSpaceNeeded + 100)){
                        Write-Host "RDFG" $rdfgDs "will have less than 100GB after the move, please request for more storage" -ForegroundColor Red
                        Read-Host -prompt "Continue? or ctrl-C to Quit"
                    }           
                        Get-VM $vm.Name | Move-VM -Datastore $rdfgDs -DiskStorageFormat Thin -RunAsync
        }
}

$tasks = Get-Task -Status Running | where{$_.Name -like "*RelocateVM_Task*"}
while($tasks.count -gt 0){
    Start-Sleep -Seconds 30
    Write-Host "Waiting for migration to finalize" -ForegroundColor Green
    $tasks = Get-Task -Status Running | where{$_.Name -like "*RelocateVM_Task*"}
}

Write-Host "Please wait while VMs are discovered" -ForegroundColor Green    
Start-Sleep -Seconds 30

#Configures Protection Group
foreach($vm in $vmsDSInfo){
    $srmPG = Get-SrmProtectionGroup |?{$_.name -match $vm.RDFG}
    Write-Host "Adding" $vm.Name "to" $srmPG.Name "Protection Group" -ForegroundColor Green
    $protectStatus = Get-VM $vm.name | Protect-SrmVM -ProtectionGroup $srmPG
    if($protectStatus.State -eq "success"){
        Write-Host $vm.Name added to $srmPG.Name successfully -ForegroundColor Green
        $protectStatus
    }else{
        Write-Host Failed to add $vm.Name to $srmPg.Name -ForegroundColor Red
        $protectStatus
    }
}

disconnectExit


