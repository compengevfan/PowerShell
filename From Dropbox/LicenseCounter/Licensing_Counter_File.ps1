$P10Creds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\ff.p10-Creds.xml'
$FanaticsCreds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\fanatics.com-Creds.xml'
$FFCreds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\ff.wh-Creds.xml'
$DreamsCreds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\dreams-Creds.xml'
$AuthenticCreds = Import-CliXml -Path 'C:\Cloud\Dropbox\Scripts\Credentials\authentic-Creds.xml'

write-host ("Getting List of VMs...")
$VMs = Get-Content .\ServerList.txt
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
	
	Write-Progress -Activity "Processing Servers" -status "Checking Server $i ($VM) of $NumberOfServers" -percentComplete ($i / $NumberOfServers*100)
	
    if ($VM -like "*FF.P10")
    {
        $VerAndEdi = gwmi -ComputerName $VM win32_operatingsystem -ErrorAction SilentlyContinue | % caption
        $Cores = gwmi -ComputerName $VM Win32_ComputerSystem -ErrorAction SilentlyContinue | % NumberOfLogicalProcessors
        if ($VerAndEdi -eq $NULL)
        { 
            $VMError = $VM
            $VMError | Out-File .\LicensingFiles\FFP10Servers.txt -Append
        }
    }

    if ($VM -like "*fanatics.corp")
    {
        $VerAndEdi = gwmi -ComputerName $VM -Credential $FanaticsCreds win32_operatingsystem -ErrorAction SilentlyContinue | % caption
        $Cores = gwmi -ComputerName $VM -Credential $FanaticsCreds Win32_ComputerSystem -ErrorAction SilentlyContinue | % NumberOfLogicalProcessors
        if ($VerAndEdi -eq $NULL) 
        { 
            $VMError = $VM
            $VMError | Out-File .\LicensingFiles\FanServers.txt -Append
        }
    }

    if ($VM -like "*footballfanatics.wh")
    {
        $VerAndEdi = gwmi -ComputerName $VM -Credential $FFCreds win32_operatingsystem -ErrorAction SilentlyContinue | % caption
        $Cores = gwmi -ComputerName $VM -Credential $FFCreds Win32_ComputerSystem -ErrorAction SilentlyContinue | % NumberOfLogicalProcessors
        if ($VerAndEdi -eq $NULL) 
        { 
            $VMError = $VM
            $VMError | Out-File .\LicensingFiles\FFWHServers.txt -Append
        }
    }

    if ($VM -like "*dreams.corp")
    {
        $VerAndEdi = gwmi -ComputerName $VM -Credential $DreamsCreds win32_operatingsystem -ErrorAction SilentlyContinue | % caption
        $Cores = gwmi -ComputerName $VM -Credential $DreamsCreds Win32_ComputerSystem -ErrorAction SilentlyContinue | % NumberOfLogicalProcessors
        if ($VerAndEdi -eq $NULL) 
        { 
            $VMError = $VM
            $VMError | Out-File .\LicensingFiles\DreamsServers.txt -Append
        }
    }

    if ($VM -like "*authentic.corp")
    {
        $VerAndEdi = gwmi -ComputerName $VM -Credential $AuthenticCreds win32_operatingsystem -ErrorAction SilentlyContinue | % caption
        $Cores = gwmi -ComputerName $VM -Credential $AuthenticCreds Win32_ComputerSystem -ErrorAction SilentlyContinue | % NumberOfLogicalProcessors
        if ($VerAndEdi -eq $NULL) 
        { 
            $VMError = $VM
            $VMError | Out-File .\LicensingFiles\AuthenticServers.txt -Append
        }
    }

    if ($VerAndEdi -ne $NULL)
    {
        if ($VerAndEdi -like "*2003, Standard*") {$2K3StdServerCount += 1; $2K3StdCoreCount += $Cores}

        if ($VerAndEdi -like "*2003, Enterprise*") {$2K3EntServerCount += 1; $2K3EntCoreCount += $Cores}
            
        if ($VerAndEdi -like "*2008 Standard*") {$2K8StdServerCount += 1; $2K8StdCoreCount += $Cores}
            
        if ($VerAndEdi -like "*2008 Enterprise*") {$2K8EntServerCount += 1; $2K8EntCoreCount += $Cores}
            
        if ($VerAndEdi -like "*2008 R2 Standard*") {$2k8R2StdServerCount += 1; $2k8R2StdCoreCount += $Cores}
            
        if ($VerAndEdi -like "*2008 R2 Enterprise*") {$2k8R2EntServerCount += 1; $2k8R2EntCoreCount += $Cores}
            
        if ($VerAndEdi -like "*2012 Standard*") {$2K12StdServerCount += 1; $2K12StdCoreCount += $Cores}
            
        if ($VerAndEdi -like "*2012 Enterprise*") {$2K12EntServerCount += 1; $2K12EntCoreCount += $Cores}
            
        if ($VerAndEdi -like "*2012 R2 Standard*") {$2K12R2StdServerCount += 1; $2K12R2StdCoreCount += $Cores}
            
        if ($VerAndEdi -like "*2012 R2 Enterprise*") {$2K12R2EntServerCount += 1; $2K12R2EntCoreCount += $Cores}
    }
    if ($VerAndEdi) { Clear-Variable VerAndEdi }
    if ($Cores) { Clear-Variable Cores }
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