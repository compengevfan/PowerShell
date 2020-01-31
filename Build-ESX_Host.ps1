<#
Script: Build-ESX_Host.ps1
Author: Joe Titra
Version: 0.1
Description: Creates custom ISO, builds host. Use Add-ESX_Host to complete host builds.
.EXAMPLE
  PS> .\Build-ESX_Host -Server <newservername>
#>
[cmdletbinding()]
Param (
    $server = "tjaxl0101esx",
    $logFolder = "\\appshare\techvirt\vmware_esx\logs\esxihostbuildlogs",
    $isoLocation = "\\appshare\techvirt\vmware_esx\VMware_vSphere_ISOs",
    $isoWebStore = "\\worker-mjaxp\ISO",
    $dracName = $($server + "-rac"),
    $ErrorActionPreference = "Stop"
)

function validatePW($pw1,$pw2){
    if($pw1.GetNetworkCredential().Password -eq $pw2.GetNetworkCredential().Password){
        return $pw1
    }
    else{
        return $null
    }
}

function drawMenu($options){
    Write-Host "CSX ESXi Host Build Utility"
    Write-Host "Choose which version you'd like to install"
    Write-Host ""
    $count = 1
    foreach($option in $options){
        Write-Host "$count. $option"
        $count++
    }
    Write-Host ""
    $option = Read-Host "1-$($count-1), exit"
    return ($option -1)
}

#Check script is running on a worker and import credentials
if($env:COMPUTERNAME -eq 'TJAXT80340APP'){ #worker-tjaxt
    if($env:USERNAME -eq 'z_vmware'){
        $esxPW = Import-CliXml ($env:githome + "\powershell\etc\cred\esxroot-worker_tjaxt.xml")
        $dracPW = Import-CliXml ($env:githome + "\powershell\etc\cred\iDRAC-worker_tjaxt.xml")
    }
    else{
        $esxPW = validatePW (Get-Credential -UserName root -Message "Enter root credentials for VMhost") (Get-Credential -UserName root -Message "ReEnter root credentials for VMhost")
        if(!($esxPW)){
            Write-Host "Passwords entered do not match. Try again" -ForegroundColor "Yellow"
            $esxPW = validatePW (Get-Credential -UserName root -Message "Enter root credentials for VMhost") (Get-Credential -UserName root -Message "ReEnter root credentials for VMhost")
            if(!($esxPW)){
                Write-Host "Passwords entered do not match." -ForegroundColor "Red"
                break
            }
        }
        $dracPW = (Get-Credential -UserName CPSAdmin -Message "Enter CPSAdmin credentials for VMhost RAC")
    }
}
elseif($env:COMPUTERNAME -eq 'TJAXP80341APP'){ #worker-tjaxp
    if($env:USERNAME -eq 'z_vmware'){
        $esxPW = Import-CliXml ($env:githome + "\powershell\etc\cred\esxroot-worker_tjaxp.xml")
        $dracPW = Import-CliXml ($env:githome + "\powershell\etc\cred\iDRAC-worker_tjaxp.xml")
    }
    else{
        $esxPW = validatePW (Get-Credential -UserName root -Message "Enter root credentials for VMhost") (Get-Credential -UserName root -Message "ReEnter root credentials for VMhost")
        if(!($esxPW)){
            Write-Host "Passwords entered do not match. Try again" -ForegroundColor "Yellow"
            $esxPW = validatePW (Get-Credential -UserName root -Message "Enter root credentials for VMhost") (Get-Credential -UserName root -Message "ReEnter root credentials for VMhost")
            if(!($esxPW)){
                Write-Host "Passwords entered do not match." -ForegroundColor "Red"
                break
            }
        }
        $dracPW = (Get-Credential -UserName CPSAdmin -Message "Enter CPSAdmin credentials for VMhost RAC")
    }
}
else{
    Write-Host "Don't pull a Trex.." -ForegroundColor "Red"
    Write-Host "Script should be run on worker-tjaxp or worker-tjaxt" -ForegroundColor "Red"
    break
}

$timeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$esxFqdn = $server.Split(".")[0].ToLower() + ".csxt.csx.com"
if(!(Test-Path $logFolder\$server)){
    New-Item $logFolder\$server -Type Directory | Out-Null
}
$logPath = ($logFolder+"\"+$server+"\"+$timeStamp+"-"+$esxFqdn+".log")
$null = try{Stop-Transcript} catch{}
Start-Transcript -Path $logPath -Append | Out-Null
if($server -like $null -or $server.Count -gt 1){
    "Error: A single server name is required"
    break
}

if(!((Get-ChildItem HKCU:\Software).Name -match "MagicISO")){
    New-Item -Path HKCU:\Software\MagicISO -Type Directory | Out-Null
    Set-ItemProperty -Path HKCU:\Software\MagicISO -Name "RegUserName" -Value "CSX"
    Set-ItemProperty -Path HKCU:\Software\MagicISO -Name "RegSerialKey" -Value "2dHR1M&Z84Vycd45vyjj_4CS0bFOWkUyI9A19cITnrfgx_7U_qxKMLGpalk1O5h&f_L7ganYDxFQjY9UHGF6AFjyCZE568gEd_QnIccaisJItRUaMF2Ve08WRuFxg86KCAyazMPYdDIN9Ff3tMRa79eMvchu0AhFzoLSunQgJi3"
}

#Get ISO
$options = Get-ChildItem $isoLocation
$option = drawMenu $options.Name.Replace(".lnk","")
if($option -eq "exit"){break}
$targetPath = (New-Object -COM WScript.Shell).CreateShortcut($options[$option].FullName).TargetPath
$sourceISO = (Get-ChildItem $targetPath | where{$_.Extension -eq ".iso"}).FullName
Write-Host "This install will use: $($sourceISO.Split("\")[-1])"

#Build Kick Start
$ips = Import-Csv $($env:githome + "\powershell\etc\Add-ESX_Host_Network.csv") | where{$_.VMHost -like $esxFqdn.Split(".")[0]}
$ks = Get-Content $($env:githome + "\powershell\etc\KS.CFG") | %{ $_ -Replace "PASSWORD",$esxPW.GetNetworkCredential().Password } | %{ $_ -Replace "IPADDRESS",$ips.SC_IP } | %{ $_ -Replace "NETWORKMASK",$ips.SC_SM } | %{ $_ -Replace "NETWORKGATEWAY",$ips.SC_GW } | %{ $_ -Replace "VLANNUM",$ips.SC_VLAN } | %{ $_ -Replace "VMHOSTNAME",$esxFqdn } | %{ $_ -Replace "DNSSERVER",$ips.DNS1 } | Out-File $logFolder\$server\KS.CFG -Encoding ascii
#Create Host Specific ISO
$targetISO = ($logFolder+"\"+$server+"\"+$($sourceISO.Split("\")[-1].Replace(".iso",""))+"-"+$server+".iso")
Write-Host "Creating ISO for $server"
Copy-Item $sourceISO -Destination $targetISO
Write-Host "Adding the KickStart File to the ISO"
$fullIsoPath = (Get-ChildItem $logFolder\$server | where {$_.Extension -eq ".iso" -and $_.Name -match $server})
$fullKsPath = (Get-ChildItem $logFolder\$server | where {$_.Extension -eq ".CFG" -and $_.Name -match "KS"})
#Extract BOOT.CFG from ISO
miso.exe $fullIsoPath.FullName -x $($fullIsoPath.DirectoryName) "BOOT.CFG" | Out-Null
$renameCfg = Copy-Item $logFolder\$server\BOOT.CFG $logFolder\$server\defaultBOOT.CFG
#Modify BOOT.CFG
#Changes for 6.5 iso
if($targetISO -like "*6.5*"){
    $bootCfg = Get-Content $logFolder\$server\defaultBOOT.CFG | %{ $_ -Replace "kernelopt=runweasel","kernelopt=runweasel ks=cdrom:/KS.CFG" } | Out-File $logFolder\$server\BOOT.CFG -Encoding ascii
}
else{
    $bootCfg = Get-Content $logFolder\$server\defaultBOOT.CFG | %{ $_ -Replace "kernelopt=runweasel","kernelopt=ks=cdrom:/KS.CFG" } | Out-File $logFolder\$server\BOOT.CFG -Encoding ascii
}
$fullCfgPath = (Get-ChildItem $logFolder\$server | where {$_.Extension -eq ".CFG" -and $_.Name -eq "BOOT.CFG"})
#Inject KS into ISO
miso.exe $fullIsoPath.FullName -d "BOOT.CFG"
miso.exe $fullIsoPath.FullName -f "EFI\BOOT" -d "BOOT.CFG"
miso.exe $fullIsoPath.FullName -a ($($fullCfgPath.DirectoryName)+"\"+$($fullCfgPath.Name))
miso.exe $fullIsoPath.FullName -f "EFI\BOOT" -a ($($fullCfgPath.DirectoryName)+"\"+$($fullCfgPath.Name))
miso.exe $fullIsoPath.FullName -a ($($fullKsPath.DirectoryName)+"\"+$($fullKsPath.Name))
miso.exe $fullIsoPath.FullName -f "EFI\BOOT" -a ($($fullKsPath.DirectoryName)+"\"+$($fullKsPath.Name))
#Reset Console Colors
$null = ($HOST.UI.RawUI.BackgroundColor = "DarkMagenta")
$null = ($HOST.UI.RawUI.ForegroundColor = "DarkYellow")
#Copy ISO to HTTP Enabled Share
if(!(Test-Path $isoWebStore\$server)){
    New-Item $isoWebStore\$server -Type Directory | Out-Null
}
Write-Host "Copying $targetISO to $isoWebStore\$server"
Copy-Item $targetISO -Destination "$isoWebStore\$server"
$hostBuild = "z_hostbuild"
$connection = Test-Connection -Server $($isoWebStore.Split("\")[2]) -Count 1
$workerIP = $connection.IPV4Address.IPAddressToString
$dracISO = ("$isoWebStore\$server\$($targetISO.Split("\")[-1])").Replace($($isoWebStore.Split("\")[2]),$workerIP).Replace("\","/")
Write-Host $dracISO
#Mount ISO to DRAC
Write-Host "Mounting ISO to DRAC"
$dracCommand = "racadm remoteimage -c -u $("./\" + $hostBuild) -p $hostBuild -l " + $dracISO
$null = echo y | plink.exe $dracName -l $($dracPW.UserName) -pw $($dracPW.GetNetworkCredential().Password) "exit"
$mountISO = plink.exe $dracName -l $($dracPW.UserName) -pw $($dracPW.GetNetworkCredential().Password) $dracCommand
#Check Status of ISO Mount
Write-Host "Checking status of ISO Mount"
$mountStatus = plink.exe $dracName -l $($dracPW.UserName) -pw $($dracPW.GetNetworkCredential().Password) "racadm remoteimage -s"
if($mountStatus -match "Remote File Share is Enabled" -and $mountStatus -match $server){
    Write-Host "ISO is connected"
}
else{
    Write-Host "There was an issue mounting the ISO, please check DRAC before continuing." -ForegroundColor "Yellow"
    Read-Host "Press any key to continue"
}
break
#Set "Next Boot" Option
plink.exe $dracName -l $($dracPW.UserName) -pw $($dracPW.GetNetworkCredential().Password) "racadm config -g cfgServerInfo -o cfgServerBootOnce 1" | Out-Null
plink.exe $dracName -l $($dracPW.UserName) -pw $($dracPW.GetNetworkCredential().Password) "racadm config -g cfgServerInfo -o cfgServerFirstBootDevice VCD-DVD" | Out-Null
#Power Cycle System
$response = (Read-Host "Are you ready to reboot the host?")
if($response -like "y*"){
    plink.exe $dracName -l $($dracPW.UserName) -pw $($dracPW.GetNetworkCredential().Password) "racadm serveraction powercycle"
}
else{
    Write-Host "You chose not to reboot the host. Please reboot manually to start the install." -ForegroundColor "Yellow"
}
#Sanitize KS
$ks = Get-Content $("$logFolder\$server" + "\KS.CFG") | %{ $_ -Replace $esxPW.GetNetworkCredential().Password,"!!REMOVED!!" } 
$ks | Out-File $logFolder\$server\KS.CFG -Encoding ascii
#Remove Staging ISO
Remove-Item -Path $targetISO -Confirm:$false
#Wait for Install to Complete
Write-Host "Waiting for install to complete"
Start-Sleep 1200
Write-Host "Trying to ping $server to see if it is alive"
$desired = "True"
$testcon = Test-Connection $server -Count 1 -Quiet
if($testcon -match "False"){
    do{
        Write-Host "$server is not alive yet waiting another minute"
        Start-Sleep 60
        Write-Host "Checking to see if $server is alive"
        $testcon = (Test-Connection $server -Count 1 -Quiet) 
    } 
    until($testcon -eq $desired)        
}
Write-Host "New host $server is alive"
#Unmount ISO from Host and Delete
plink.exe $dracName -l $($dracPW.UserName) -pw $($dracPW.GetNetworkCredential().Password) "racadm remoteimage -d"
Remove-Item -Path $("$isoWebStore\$server\$($targetISO.Split("\")[-1])") -Confirm:$false
Write-Host "Install Complete. Run 'Add-ESX_Host -server $server' to complete build process"
Stop-Transcript | Out-Null