[CmdletBinding()]
Param(
    [Parameter()] [string] [ValidateSet("avrora","phoenix")] $clusterToDeploy
)

#Requires -Version 7

# $timeStamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"

#Verify Prerequisites
#Ensure vault token cred file exists
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; throw 66 }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }

#Setup cluster install folder and copy generic yaml file
$genericYamlFile = Get-Item -Path "~/git/okd/clusterinstall/install-config.yaml"
if (Test-Path "~/$clusterToDeploy-install") {
    Remove-Item -Path "~/$clusterToDeploy-install" -Recurse -Force
}
$deployPath = New-Item -Path "~" -Name "$clusterToDeploy-install" -ItemType "directory"
Copy-Item $genericYamlFile $deployPath

#Get Info From Vault
#Set Common Info
Import-DfCredentials
$apiToken = $Credvaulttoken.GetNetworkCredential().Password
$header = @{"X-Vault-Token"="$apiToken"}
#Get Proxmox secrets
#Root
$uriProxmox = "https://vault.evorigin.com:8200/v1/HomeLabSecrets/data/proxmox/root"
$resultsProxmoxRoot = Invoke-RestMethod -Uri $uriProxmox -Method Get -Headers $header -SkipCertificateCheck
#Create Proxmox Token
$proxmoxToken = "PVEAPIToken=$($resultsProxmoxRoot.data.data.apitokenid)=$($resultsProxmoxRoot.data.data.apisecret)"
#Bootstrap VM info
$uriProxmox = "https://vault.evorigin.com:8200/v1/HomeLabSecrets/data/okd/vms/okd-$clusterToDeploy-bs1"
$resultsProxmoxBs = Invoke-RestMethod -Uri $uriProxmox -Method Get -Headers $header -SkipCertificateCheck
#Control Plane VM Info
$uriProxmox = "https://vault.evorigin.com:8200/v1/HomeLabSecrets/data/okd/vms/okd-$clusterToDeploy-cp1"
$resultsProxmoxCp = Invoke-RestMethod -Uri $uriProxmox -Method Get -Headers $header -SkipCertificateCheck
#Worker1 VM Info
$uriProxmox = "https://vault.evorigin.com:8200/v1/HomeLabSecrets/data/okd/vms/okd-$clusterToDeploy-wk1"
$resultsProxmoxWk1 = Invoke-RestMethod -Uri $uriProxmox -Method Get -Headers $header -SkipCertificateCheck
#Worker2 VM Info
$uriProxmox = "https://vault.evorigin.com:8200/v1/HomeLabSecrets/data/okd/vms/okd-$clusterToDeploy-wk1"
$resultsProxmoxWk2 = Invoke-RestMethod -Uri $uriProxmox -Method Get -Headers $header -SkipCertificateCheck
#Get okd secrets
$uriK8s = "https://vault.evorigin.com:8200/v1/HomeLabSecrets/data/okd/install"
$resultsK8s = Invoke-RestMethod -Uri $uriK8s -Method Get -Headers $header -SkipCertificateCheck

$installContent = Get-Content $deployPath/install-config.yaml
$installContent = $installContent.Replace("[clustername]",$clusterToDeploy)
$installContent = $installContent.Replace("[pullsecret]",$resultsK8s.data.data.pullSecret)
$installContent = $installContent.Replace("[sshkey]",$resultsK8s.data.data.sshKey_public)
Set-Content -Value $installContent -Path $deployPath/install-config.yaml -Force

#Create Manifests
openshift-install create manifests --dir="$deployPath"
Start-Sleep 5

#Create Ignition Files
openshift-install create ignition-configs --dir="$deployPath"
Start-Sleep 5

# Copy the SCOS ISO to the install folder
Copy-Item ~/scos*.iso $deployPath/scos-original.iso
Start-Sleep 5

#Shutdown and Delete VMs if they exist
$allVms = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $proxmoxToken -Method "GET" -Endpoint "/api2/json/cluster/resources?type=vm"
$clusterVms = $allVms.data | Where-Object {$_.name -like "*$clusterToDeploy*"}
foreach ($Vm in $clusterVms) {
    if ($Vm.status -eq "running") { 
        Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $proxmoxToken -Method "POST" -Endpoint "/api2/json/nodes/$($Vm.node)/qemu/$($Vm.vmid)/status/stop"
        while ($Check.data.status -ne "stopped") {start-sleep 10; $Check = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $proxmoxToken -Method "GET" -Endpoint "/api2/json/nodes/$($Vm.node)/qemu/$($Vm.vmid)/status/current" } 
    }
    Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $proxmoxToken -Method "DELETE" -Endpoint "/api2/json/nodes/$($Vm.node)/qemu/$($Vm.vmid)"
}

#Inject ignition files
Set-Location $deployPath
podman run --privileged --rm -v .:/data -w /data quay.io/coreos/coreos-installer:release iso customize --dest-device /dev/sda --dest-ignition bootstrap.ign -o scos-bootstrap.iso scos-original.iso
podman run --privileged --rm -v .:/data -w /data quay.io/coreos/coreos-installer:release iso customize --dest-device /dev/sda --dest-ignition master.ign -o scos-master.iso scos-original.iso
podman run --privileged --rm -v .:/data -w /data quay.io/coreos/coreos-installer:release iso customize --dest-device /dev/sda --dest-ignition worker.ign -o scos-worker.iso scos-original.iso
Set-Location /root

#Create New VMs
$nextVmid = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $proxmoxToken -Method "GET" -Endpoint "/api2/json/cluster/nextid"
$PutBody = @{
    vmid        =$($nextVmid.data)
    node        ="pmx1"
    name        ="okd-$clusterToDeploy-bs1"
    ostype      ="l26"
    machine     ="q35"
    bios        ="ovmf"
    scsihw      ="virtio-scsi-pci"
    agent       =1
    cores       =4
    memory      =16384
    ide2        ="ISOs_Linux:iso/scos-bootstrap.iso,media=cdrom"
}
$bootstrapVm = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $proxmoxToken -Method "POST" -Body $PutBody -Endpoint "/api2/json/nodes/$($resultsProxmoxBs.data.data.host)/qemu"
Remove-Variable PutBody
$controlPlaneVm = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $proxmoxToken -Method "POST" -Endpoint "/api2/json/nodes/$($resultsProxmoxCp.data.data.host)/qemu"
$worker1Vm = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $proxmoxToken -Method "POST" -Endpoint "/api2/json/nodes/$($resultsProxmoxWk1.data.data.host)/qemu"
$worker2Vm = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $proxmoxToken -Method "POST" -Endpoint "/api2/json/nodes/$($resultsProxmoxWk2.data.data.host)/qemu"

#Install Root CA and Replace Default Ingress Cert
$success = Read-Host "Was cluster creation successful? (y|n)"

if ($success -eq "y" -and $clusterToDeploy -eq "phoenix") {
    $rootpassword = Get-Content $deployPath/auth/kubeadmin-password
    oc login -u kubeadmin -p $rootpassword --server=https://api.phoenix.evorigin.com:6443
    
    oc create configmap evorigin-ca --from-file=ca-bundle.crt=/home/ladmin/install_phoenix/certs/ca.crt -n openshift-config
    oc patch proxy/cluster --type=merge --patch='{"spec":{"trustedCA":{"name":"evorigin-ca"}}}'
    oc create secret tls cluster-ingress --cert=/home/ladmin/install_phoenix/certs/Openshift-Phoenix-Ingress.crt --key=/home/ladmin/install_phoenix/certs/Openshift-Phoenix-Ingress-Decrypted.key -n openshift-ingress
    oc patch ingresscontroller.operator default --type=merge -p '{"spec":{"defaultCertificate": {"name": "cluster-ingress"}}}' -n openshift-ingress-operator
}

if ($success -eq "y" -and $clusterToDeploy -eq "avrora") {
    $rootpassword = Get-Content $deployPath/auth/kubeadmin-password
    oc login -u kubeadmin -p $rootpassword --server=https://api.avrora.evorigin.com:6443

    oc create configmap evorigin-ca --from-file=ca-bundle.crt=/home/ladmin/install_avrora/certs/ca.crt -n openshift-config
    oc patch proxy/cluster --type=merge --patch='{"spec":{"trustedCA":{"name":"evorigin-ca"}}}'
    oc create secret tls cluster-ingress --cert=/home/ladmin/install_avrora/certs/Openshift-Avrora-Ingress.crt --key=/home/ladmin/install_avrora/certs/Openshift-Avrora-Ingress-Decrypted.key -n openshift-ingress
    oc patch ingresscontroller.operator default --type=merge -p '{"spec":{"defaultCertificate": {"name": "cluster-ingress"}}}' -n openshift-ingress-operator
}