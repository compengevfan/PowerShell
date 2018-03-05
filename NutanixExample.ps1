#### IGNORE SSL CERTS ####

Add-Type @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            ServicePointManager.ServerCertificateValidationCallback += 
                delegate
                (
                    Object obj, 
                    X509Certificate certificate, 
                    X509Chain chain, 
                    SslPolicyErrors errors
                )
                {
                    return true;
                };
        }
    }
"@
 
[ServerCertificateValidationCallback]::Ignore();


#### StoreCredentials ####
$username = "admin"
$password = "password"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))

#### Set Headers ####
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Basic $base64AuthInfo")

#### Ask for VM Name ####

Write-Host "What would you like to name the test VM?"

$vmName = Read-Host

$service_url = "https://10.68.69.102:9440/api/nutanix/v2.0"

# Get VMs
$vms = "$service_url/vms/"

$GetVMs = (Invoke-RestMethod -Method Get -Uri $vms -Headers $headers).entities

$GetVMs | ft name, uuid

$body = @"
{
   "description":"Tech Summit 2017",
   "guest_os":"Windows Server 2012 R2",
   "memory_mb":4096,
   "name":"$vmName",
   "num_cores_per_ vcpu":2,
   "num_vcpus":1,
   "vm_disks":[
      {
         "disk_address":{
            "device_bus":"ide",
            "device_index":0
         },
         "is_cdrom":true,
         "is_empty":false,
         "vm_disk_clone":{
            "disk_address":{
               "vmdisk_uuid":"56dfaae9-fb54-4771-b91c-89aa6907a4fc"
            }
         }
      },
      {
         "disk_address":{
            "device_bus":"scsi",
            "device_index":0
         },
         "vm_disk_create":{
            "storage_container_uuid":"2a18ba2d-ce9c-481a-bfea-268f818469b3",
            "size":10737418240
         }
      },
      {
         "disk_address":{
            "device_bus":"ide",
            "device_index":1
         },
         "is_ cdrom":true,
         "is_empty":false,
         "vm_disk_clone":{
            "disk_address":{
               "vmdisk_uuid":"cc593ed9-29e8-4ced-b8e7-c469d46bbf75"
            }
         }
      }
   ],
   " hypervisor_type":"ACROPOLIS",
   "affinity":null
}
"@


Invoke-RestMethod -Method Post -Uri $vms -Headers $headers -Body $body -ContentType 'application/json'

"Waiting for VM to create..."
Start-Sleep -Seconds 5

$GetVMs = (Invoke-RestMethod -Method Get -Uri $vms -Headers $headers).entities

$createdVMs = $GetVMs | where {$_.name -eq "$vmName"} | Select-Object name, uuid

foreach ($selectedVM in $createdVMs){

    "The VM you created is $($selectedVM.name) and the UUID is $($selectedVM.uuid)."


    "Powering on VM $($selectedVM.name)..."

    $body = @"
    {
      "transition": "ON",
      "uuid": "$($selectedVM.uuid)"
    }
"@

    Invoke-RestMethod -Method Post -Uri "$vms$($selectedVM.uuid)/set_power_state/" -Headers $headers -Body $body -ContentType 'application/json'

    Write-Host "Verify VM is powered on - then hit enter to delete."
    Read-Host

    "Deleting $($selectedVM.name)..."

    Invoke-RestMethod -Method Delete -Uri "$vms$($selectedVM.uuid)/" -Headers $headers -ContentType 'application/json'

}