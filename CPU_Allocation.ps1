<#
What does the script do?
Provides CPU and RAM allocation to available ratios for all clusters and hosts managed by a vCenter server. information is written to a text file located on the C drive in a folder called "ScriptOutput".

Where/How does the script run?
The script can be run from anywhere that has access to connect to the vCenter server.

What account do I run it with?
No specific account is needed. Your own login will work.

What is the syntax for executing?
CPU_Allocation.ps1 [-vCenter <string>]

What does this script need to function properly?
1. "DupreeFunctions" PowerShell module in a path that is listed in the PSModulePath environment variable. I recommend "%ProgramFiles%\WindowsPowerShell\Modules".
2. PowerCLI must be installed.
#>

[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter
)

$ScriptPath = $PSScriptRoot
cd $ScriptPath

Function Check-PowerCLI
{
    Param(
    )

    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
	    write-host ("Adding PowerCLI...")
        Get-Module -Name VMware* -ListAvailable | Import-Module -Global
	    write-host ("Loaded PowerCLI.")
    }
}

if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }

Check-PowerCLI
 
$a = Read-Host "Do you have a credential file? (y/n)"
Remove-Variable Credential_To_Use -ErrorAction Ignore
if ($a -eq "y") { Write-Host "Please select a credential file..."; $CredFile = Get-DfFileName -Filter "xml" }
New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
 
Connect-DFvCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

if (!(Test-Path "C:\ScriptOutput"))
{
    New-Item "C:\ScriptOutput" -ItemType directory
}

$Date = Get-Date -Format "MM-dd-yyyy"
$FileLocation = "C:\ScriptOutput\CPU Allocation " + $Date + ".txt"

write-host("Retrieving list of Clusters...")
$Clusters = get-cluster | Sort-Object Name

write-host("Retrieving list of Hosts...")
$VMHosts = get-vmhost | Sort-Object Name

write-host("Retrieving list of VMs...")
$VMs = get-vm | where {$_.PowerState -eq "PoweredOn"} | Sort-Object Name

[int] $ClusterCPUsAvail = 0
[int] $ClusterCPUsAlloc = 0

[int] $HostCPUsAvail = 0
[int] $HostCPUsAlloc = 0

[int] $ClusterMemAvail = 0
[int] $ClusterMemAlloc = 0

[int] $HostMemAvail = 0
[int] $HostMemAlloc = 0

$TempString = ""

foreach ($Cluster in $Clusters)
{
	write-host ("Processing Cluster " + $Cluster + ".")
	
	$TempString = "Current Cluster is " + $Cluster + "."
	$TempString | out-file $FileLocation -append
	
	$CurrClusterHosts = $VMHosts | where {$_.Parent.Name -eq $Cluster}
	
	foreach ($CurrClusterHost in $CurrClusterHosts)
	{
		$CurrHostVMs = $VMs | where {$_.VMHost.Name -eq $CurrClusterHost}
		
		foreach ($CurrHostVM in $CurrHostVMs)
		{
			$HostCPUsAlloc += $CurrHostVM.NumCPU
			$HostMemAlloc += $CurrHostVM.MemoryGB
		}
		
		$HostCPUsAvail = $CurrClusterHost.NumCPU
		$HostMemAvail = $CurrClusterHost.MemoryTotalGB
		
		$TempString = ""
		$TempString | out-file $FileLocation -append
		$TempString = "Current host is " + $CurrClusterHost + "."
		$TempString | out-file $FileLocation -append
		$TempString = "Allocated CPUs: " + $HostCPUsAlloc + "."
		$TempString | out-file $FileLocation -append
		$TempString = "Available CPUs: " + $HostCPUsAvail + "."
		$TempString | out-file $FileLocation -append
		
		$Ratio = $HostCPUsAlloc / $HostCPUsAvail
		
		$TempString = "Ratio is " + $Ratio + "."
		$TempString | out-file $FileLocation -append
		
		$TempString = ""
		$TempString | out-file $FileLocation -append
		$TempString = "Allocated Memory: " + $HostMemAlloc + "."
		$TempString | out-file $FileLocation -append
		$TempString = "Available Memory: " + $HostMemAvail + "."
		$TempString | out-file $FileLocation -append
		
		$Ratio = $HostMemAlloc / $HostMemAvail
		
		$TempString = "Ratio is " + $Ratio + "."
		$TempString | out-file $FileLocation -append
		
		$ClusterCPUsAlloc += $HostCPUsAlloc
		$ClusterMemAlloc += $HostMemAlloc
		
		$ClusterCPUsAvail += $HostCPUsAvail
		$ClusterMemAvail += $HostMemAvail
		
		$HostCPUsAlloc = 0
		$HostMemAlloc = 0
	}
	
	$TempString = ""
	$TempString | out-file $FileLocation -append
	$TempString = "Cluster Allocated CPUs: " + $ClusterCPUsAlloc + "."
	$TempString | out-file $FileLocation -append
	$TempString = "Cluster Available CPUs: " + $ClusterCPUsAvail + "."
	$TempString | out-file $FileLocation -append
	
	$Ratio = $ClusterCPUsAlloc / $ClusterCPUsAvail
	
	$TempString = "Ratio is " + $Ratio + "."
	$TempString | out-file $FileLocation -append
	
	$TempString = ""
	$TempString | out-file $FileLocation -append
	$TempString = "Cluster Allocated Memory: " + $ClusterMemAlloc + "."
	$TempString | out-file $FileLocation -append
	$TempString = "Cluster Available Memory: " + $ClusterMemAvail + "."
	$TempString | out-file $FileLocation -append
	
	$Ratio = $ClusterMemAlloc / $ClusterMemAvail
	
	$TempString = "Ratio is " + $Ratio + "."
	$TempString | out-file $FileLocation -append
	
	$TempString = ""
	$TempString | out-file $FileLocation -append
	$TempString = "=========================================================="
	$TempString | out-file $FileLocation -append
	$TempString = ""
	$TempString | out-file $FileLocation -append
	
	$ClusterCPUsAlloc = 0
	$ClusterCPUsAvail = 0
	
	$ClusterMemAlloc = 0
	$ClusterMemAvail = 0
}

write-host("")
write-host ("Data written to " + $FileLocation + ".")