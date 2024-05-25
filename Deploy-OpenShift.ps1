[CmdletBinding()]
Param(
    [Parameter()] [string] [ValidateSet("avrora","phoenix")] $clusterToDeploy
)

#Requires -Version 7

#Determine Paths
if ($IsLinux) {
    $gitRoot = Get-Item -Path "~/git"
    $clusterPath = Get-Item -Path "~/git/k8s/clusterinstall/$clusterToDeploy"
}
if ($IsWindows) {
    $gitRoot = Get-Item -Path "C:\Git"
    $clusterPath = Get-Item -Path "C:/Git/k8s/clusterinstall/$clusterToDeploy"
}

