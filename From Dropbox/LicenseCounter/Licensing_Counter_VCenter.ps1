#Script for Licensing
#Needs to determine edition and version of Windows and count of cores
#Add number of standard 2008, 2008 R2, 2012, and 2012 R2
#Add number of enterprise 2008, 2008 R2, 2012, and 2012 R2
#Core count for each as well

#Algorithm
    #Get Various credentials
    #Get List of VMs from VCenter
    #Get a server
    #Check if server is windows
    #Determine which domain the server is in
    #Attempt to wmi call and get server version and edition
        #if successful, tally server as proper edition and version and tally cores
            #Check if version and edition is in tally
        #else, write out server name to file of unsuccessful wmi, seperate file per domain


$P10Creds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\ff.p10-Creds.xml'
$FanaticsCreds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\fanatics.com-Creds.xml'
$FFCreds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\ff.wh-Creds.xml'
$DreamsCreds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\dreams-Creds.xml'
$AuthenticCreds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\authentic-Creds.xml'

$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

Remove-Item .\LicensingFiles\*.txt

if ($SnapinCheck -eq $NULL)
{
	write-host ("Adding VMware Snapin...")
	add-pssnapin VMware.VimAutomation.Core
	write-host ("Complete")
}

write-host ("Getting List of VMs...")
$VMs = Get-Cluster | ? {$_.Name -ne "DEVQC"} | Get-VM | Where-Object {$_.PowerState -eq "PoweredOn" -and $_.Name -notlike "*DEV*" -and $_.Name -notlike "*STG*" -and $_.Name -notlike "*QC*"} | Sort-Object Name
write-host ("Got VMs...")



$NumberOfServers = $VMs.Count
$i = 1

$2K3StdServerCount = 0
$2K3StdCoreCount = 0
$2K3EntServerCount = 0
$2K3EntCoreCount = 0

$2k8StdServerCount = 0
$2K8StdCoreCount = 0
$2k8EntServerCount = 0
$2K8EntCoreCount = 0

$2k8R2StdServerCount = 0
$2K8R2StdCoreCount = 0
$2k8R2EntServerCount = 0
$2K8R2EntCoreCount = 0

$2K12StdServerCount = 0
$2K12StdCoreCount = 0
$2K12EntServerCount = 0
$2K12EntCoreCount = 0

$2K12R2StdServerCount = 0
$2K12R2StdCoreCount = 0
$2K12R2EntServerCount = 0
$2K12R2EntCoreCount = 0

foreach ($VM in $VMs)
{
	
	Write-Progress -Activity "Processing Servers" -status "Checking Server $i ($($VM.Guest.HostName)) of $NumberOfServers" -percentComplete ($i / $NumberOfServers*100)
	
    if ($VM.Guest.OSFullName -like "*Windows*")
    {
        if ($VM.Guest.HostName -like "*FF.P10")
        {
            $VerAndEdi = gwmi -ComputerName $($VM.Guest.HostName) -Credential $P10Creds win32_operatingsystem -ErrorAction SilentlyContinue | % caption
            if ($VerAndEdi -eq $NULL)
            { 
                $VMError = $VM.Guest.HostName
                $VMError | Out-File .\LicensingFiles\FFP10Servers.txt -Append
            }
        }

        if ($VM.Guest.HostName -like "*fanatics.corp")
        {
            $VerAndEdi = gwmi -ComputerName $($VM.Guest.HostName) -Credential $FanaticsCreds win32_operatingsystem -ErrorAction SilentlyContinue | % caption
            if ($VerAndEdi -eq $NULL) 
            { 
                $VMError = $VM.Guest.HostName
                $VMError | Out-File .\LicensingFiles\FanServers.txt -Append
            }
        }

        if ($VM.Guest.HostName -like "*footballfanatics.wh")
        {
            $VerAndEdi = gwmi -ComputerName $($VM.Guest.HostName) -Credential $FFCreds win32_operatingsystem -ErrorAction SilentlyContinue | % caption
            if ($VerAndEdi -eq $NULL) 
            { 
                $VMError = $VM.Guest.HostName
                $VMError | Out-File .\LicensingFiles\FFWHServers.txt -Append
            }
        }
		
		if ($VM.Guest.HostName -like "*dreams.corp")
		{
			$VerAndEdi = gwmi -ComputerName $VM -Credential $DreamsCreds win32_operatingsystem -ErrorAction SilentlyContinue | % caption
			if ($VerAndEdi -eq $NULL) 
			{ 
				$VMError = $VM.Guest.HostName
				$VMError | Out-File .\LicensingFiles\DreamsServers.txt -Append
			}
		}

		if ($VM.Guest.HostName -like "*authentic.corp")
		{
			$VerAndEdi = gwmi -ComputerName $VM -Credential $AuthenticCreds win32_operatingsystem -ErrorAction SilentlyContinue | % caption
			if ($VerAndEdi -eq $NULL) 
			{ 
				$VMError = $VM.Guest.HostName
				$VMError | Out-File .\LicensingFiles\AuthenticServers.txt -Append
			}
		}

        if ($VerAndEdi -ne $NULL)
        {
            if ($VerAndEdi -like "*2003 Standard*") {$2K3StdServerCount += 1; $2K3StdCoreCount += $VM.NumCpu}

            if ($VerAndEdi -like "*2003 Enterprise*") {$2K3EntServerCount += 1; $2K3EntCoreCount += $VM.NumCpu}
            
            if ($VerAndEdi -like "*2008 Standard*") {$2K8StdServerCount += 1; $2K8StdCoreCount += $VM.NumCpu}
            
            if ($VerAndEdi -like "*2008 Enterprise*") {$2K8EntServerCount += 1; $2K8EntCoreCount += $VM.NumCpu}
            
            if ($VerAndEdi -like "*2008 R2 Standard*") {$2k8R2StdServerCount += 1; $2k8R2StdCoreCount += $VM.NumCpu}
            
            if ($VerAndEdi -like "*2008 R2 Enterprise*") {$2k8R2EntServerCount += 1; $2k8R2EntCoreCount += $VM.NumCpu}
            
            if ($VerAndEdi -like "*2012 Standard*") {$2K12StdServerCount += 1; $2K12StdCoreCount += $VM.NumCpu}
            
            if ($VerAndEdi -like "*2012 Enterprise*") {$2K12EntServerCount += 1; $2K12EntCoreCount += $VM.NumCpu}
            
            if ($VerAndEdi -like "*2012 R2 Standard*") {$2K12R2StdServerCount += 1; $2K12R2StdCoreCount += $VM.NumCpu}
            
            if ($VerAndEdi -like "*2012 R2 Enterprise*") {$2K12R2EntServerCount += 1; $2K12R2EntCoreCount += $VM.NumCpu}
        }
    }
    if ($VerAndEdi) { Clear-Variable VerAndEdi }
	$i++
}

Write-Host ("Server 2003 Standard: $2K3StdServerCount Servers; $2K3StdCoreCount Cores")
Write-Host ("Server 2003 Enterprise: $2K3EntServerCount Servers; $2K3EntCoreCount Cores")
Write-Host ("Server 2008 Standard: $2K8StdServerCount Servers; $2K8StdCoreCount Cores")
Write-Host ("Server 2008 Enterprise: $2K8EntServerCount Servers; $2K8EntCoreCount Cores")
Write-Host ("Server 2008 R2 Standard: $2k8R2StdServerCount Servers; $2k8R2StdCoreCount Cores")
Write-Host ("Server 2008 R2 Enterprise: $2k8R2EntServerCount Servers; $2k8R2EntCoreCount Cores")
Write-Host ("Server 2012 Standard: $2K12StdServerCount Servers; $2K12StdCoreCount Cores")
Write-Host ("Server 2012 Enterprise: $2K12EntServerCount Servers; $2K12EntCoreCount Cores")
Write-Host ("Server 2012 R2 Standard: $2K12R2StdServerCount Servers; $2K12R2StdCoreCount Cores")
Write-Host ("Server 2012 R2 Enterprise: $2K12R2EntServerCount Servers; $2K12R2EntCoreCount Cores")