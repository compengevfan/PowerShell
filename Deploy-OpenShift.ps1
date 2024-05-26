[CmdletBinding()]
Param(
    [Parameter()] [string] [ValidateSet("avrora","phoenix")] $clusterToDeploy
)

#Requires -Version 7

#Determine Paths
if ($IsLinux) {
    $gitRoot = Get-Item -Path "~/git"
    $clusterPath = Get-Item -Path "~/git/k8s/clusterinstall/$clusterToDeploy"
    $deployPath = Get-Item -Path "/tmp/deploy" -ErrorAction SilentlyContinue
}
if ($IsWindows) {
    $gitRoot = Get-Item -Path "C:\Git"
    $clusterPath = Get-Item -Path "C:/Git/k8s/clusterinstall/$clusterToDeploy"
}

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
if ($deployPath){
    Remove-Item /tmp/deploy/ -Recurse -Confirm:$false
}
New-Item -Path "/tmp" -Name "deploy" -ItemType "directory" | Out-Null

Copy-Item $clusterPath/install-config.yaml /tmp/deploy/install-config.yaml -Force

$installContent = Get-Content /tmp/deploy/install-config.yaml
$installContent = $installContent.Replace("[vcenterserver]",$resultsVcenter.data.data.servername)
$installContent = $installContent.Replace("[vcenterpassword]",$resultsVcenter.data.data.password)
$installContent = $installContent.Replace("[vcenteruser]",$resultsVcenter.data.data.domain + "\" + $resultsVcenter.data.data.username)
$installContent = $installContent.Replace("[pullsecret]",$resultsK8s.data.data.pullSecret)
$installContent = $installContent.Replace("[sshkey]",$resultsK8s.data.data.sshKey)
Set-Content -Value $installContent -Path /tmp/deploy/install-config.yaml -Force

openshift-install create cluster --dir /tmp/deploy --log-level=debug