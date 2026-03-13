[CmdletBinding()]
Param(
    [Parameter()] [string] [ValidateSet("avrora","phoenix")] $clusterToDeploy
)

#Requires -Version 7

# $timeStamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"

#Verify Prerequisites
#Ensure vault token cred file exists

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
$uriProxmox = "https://vault.evorigin.com:8200/v1/HomeLabSecrets/data/proxmox/root"
$resultsProxmox = Invoke-RestMethod -Uri $uriProxmox -Method Get -Headers $header -SkipCertificateCheck
#Get okd secrets
$uriK8s = "https://vault.evorigin.com:8200/v1/HomeLabSecrets/data/okd/install"
$resultsK8s = Invoke-RestMethod -Uri $uriK8s -Method Get -Headers $header -SkipCertificateCheck

$installContent = Get-Content $deployPath/install-config.yaml
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