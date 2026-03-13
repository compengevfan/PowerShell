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
Copy-Item $genericYamlFile "~/$clusterToDeploy-install"

#Get Info From Vault
#Set Common Info
$vaultCred = Import-Clixml ~/credentials/vaulttoken.xml
$apiToken = $vaultCred.GetNetworkCredential().Password
$header = @{"X-Vault-Token"="$apiToken"}
#Get vCenter secrets
$uriVcenter = "https://vault.evorigin.com:8200/v1/homelabsecrets/data/vmware/vcenter"
$resultsVcenter = Invoke-RestMethod -Uri $uriVcenter -Method Get -Headers $header
#Get k8s secrets
$uriK8s = "https://vault.evorigin.com:8200/v1/homelabsecrets/data/k8s/install"
$resultsK8s = Invoke-RestMethod -Uri $uriK8s -Method Get -Headers $header

#Modify install-config.yaml file
Copy-Item $clusterPath/install-config.yaml $deployPath/install-config.yaml -Force

$installContent = Get-Content $deployPath/install-config.yaml
$installContent = $installContent.Replace("[vcenterserver]",$resultsVcenter.data.data.servername)
$installContent = $installContent.Replace("[vcenterpassword]",$resultsVcenter.data.data.password)
$installContent = $installContent.Replace("[vcenteruser]",$resultsVcenter.data.data.domain + "\" + $resultsVcenter.data.data.username)
$installContent = $installContent.Replace("[pullsecret]",$resultsK8s.data.data.pullSecret)
$installContent = $installContent.Replace("[sshkey]",$resultsK8s.data.data.sshKey)
Set-Content -Value $installContent -Path $deployPath/install-config.yaml -Force

#Create Cluster
openshift-install create cluster --dir $deployPath --log-level=debug

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