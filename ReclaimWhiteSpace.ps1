﻿[CmdletBinding()]
Param(
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath

#Import functions
. .\Functions\Function_DoLogging.ps1
. .\Functions\function_Check-PowerCLI.ps1
. .\Functions\function_Connect-vCenter.ps1

Check-PowerCLI

Connect-vCenter

$Cluster = Read-Host -Prompt ("Please enter the name of the cluster you want to reclaim white space on")
$HostsToBalance = Get-Cluster $Cluster

Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds -1 -Confirm:$false

$ESXCLI = Get-EsxCli -v2 -VMHost $CurrentHost 

$ESXCLI.storage.vmfs.unmap.Invoke(@{reclaimunit='200';volumelabel='jaxf-vs-prod-ds01'})
