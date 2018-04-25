<#
What does the script do?
Ensures that an Ecomm server stack's VMs are running on the appropriate ESX host. Should be used if maintenance was performed on the stack or a host failure occurred which resulted in the VMs getting moved around in the vCenter cluster.

Where/How does the script run?
The script can be run from anywhere that has PowerCLI installed and connectivity to the Ecomm vCenter is available. 

What account do I run it with?
No specific account is required. 

What is the syntax for executing?
StackOrganizer.ps1

What does this script need to function properly?
PowerCLI must be loaded in your current PowerShell session. I recommend launching PowerCLI rather than PowerShell.
This script is only for Ecomm stacks that have 5 ESXi hosts.
A csv file called "StackOrganizer-Layout.csv" which contains VM to host mapping information.
#>

[CmdletBinding()]
Param(
)

#Check for vCenter Server Connection
$ConnectedvCenterCount = $global:DefaultVIServers.Count

#Obtain info from user
if ($ConnectedvCenterCount -eq 0) { $vCenter = Read-Host -Prompt ("Please enter the name of the vCenter Server"); Connect-VIServer $vCenter }
$Cluster = Read-Host -Prompt ("Please enter the name of the cluster to be organized")

$ClusterHosts = Get-Cluster $Cluster | Get-VMHost | Sort-Object Name

$StackLayout = Import-Csv .\StackOrganizer-Layout.csv

foreach ($Record in $StackLayout)
{
    $NamePart = $Record.VM
    $HostNum = $($Record.Host) - 1

    $CurrentVM = Get-Cluster $Cluster | Get-VM | Where-Object { $_.Name -like "*$NamePart" }
    if ($CurrentVM -ne $null) { Move-VM -VM $CurrentVM -Destination $ClusterHosts[$HostNum] }
}