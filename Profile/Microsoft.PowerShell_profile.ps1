<#PSScriptInfo

.VERSION 2.0.6

.GUID b53cae85-1769-4697-ba24-a6fd87efb453

.AUTHOR cdupree

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 PowerShell Profile 

#> 
Param()

#Display .NET Versions Installed
Write-Host ".NET version installed: " -NoNewline
$dotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release
switch ($dotNetVersion) {
	378389 { Write-Host "4.5" }
	{ ($_ -eq 378675) -or ($_ -eq 378758) } { Write-Host "4.5.1" }
	379893 { Write-Host "4.5.2" }
	{ ($_ -eq 393295) -or ($_ -eq 393297) } { Write-Host "4.6" }
	{ ($_ -eq 394254) -or ($_ -eq 394271) } { Write-Host "4.6.1" }
	{ ($_ -eq 394802) -or ($_ -eq 394806) } { Write-Host "4.6.2" }
	{ ($_ -eq 460798) -or ($_ -eq 460805) } { Write-Host "4.7" }
	{ ($_ -eq 461308) -or ($_ -eq 461310) } { Write-Host "4.7.1" }
	{ ($_ -eq 461808) -or ($_ -eq 461814) } { Write-Host "4.7.2" }
	{ ($_ -eq 528040) -or ($_ -eq 528372) -or ($_ -eq 528049) -or ($_ -eq 528449) } { Write-Host "4.8" }
	Default { Write-Host "Unknown build $dotNetVersion found." }
}

#Display PowerShell Version
Write-Host "`nPowerShell Version:"
$PSVersionTable.PSVersion

#Check for PowerCLI and version
$PowerCLICheck = Get-Module -ListAvailable VMware.Vim
if ($null -ne $PowerCLICheck) { Write-Host "`nPowerCLI $($PowerCLICheck.Version.Major).$($PowerCLICheck.Version.Minor) is installed." -ForegroundColor green }
else { Write-Host "`nPowerCLI not found." -ForegroundColor red }

#Check for Git environment variable
if ($env:githome) { $githome = $env:githome; Write-Host "`nGit path found." -ForegroundColor Green }
else { Write-Host "`nGit path NOT found." -ForegroundColor Red }

$LocalComputerName = [System.Net.Dns]::GetHostByName($env:computerName).HostName

if ($LocalComputerName -like "*.evorigin.com") {
	Write-Host "Detected EvOrigin Computer..." -ForegroundColor Green

	try {
		Write-Host "Importing DupreeFunctions..." -ForegroundColor Gray
		Import-Module DupreeFunctions -Force -ErrorAction Continue

		Import-Module DupreeFunctions -Force -ErrorAction Stop

		Write-Host "Importing credentials..." -ForegroundColor Gray
		Import-Credentials
	}
	catch {
		# Write-Host "DupreeFunctions NOT found." -ForegroundColor Red
		throw
	}

	#Check for Dropbox environment variable
	if ($env:dropboxhome) { $dropboxhome = $env:dropboxhome; Write-Host "Dropbox path found." -ForegroundColor Green }
	else { Write-Host "Dropbox path NOT found." -ForegroundColor Yellow }
}

else {
	Write-Host "Must be a work Computer..." -ForegroundColor Green

	try {
		Write-Host "Importing DC.Automation..." -ForegroundColor Gray
		Import-Module DC.Automation -Force -ErrorAction Continue
	}
	catch {
		Write-Host "DC.Automation NOT found." -ForegroundColor Red
	}
}


<# Write-Host "Checking DupreeFunctions module available and latest version..."
$DupreeFunctionsMinVersion = (Find-Module DupreeFunctions).Version
if (!(Get-InstalledModule -Name DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion -ErrorAction SilentlyContinue))
{
	try 
	{
		if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Install-Module -Name DupreeFunctions -Scope CurrentUser -Force -ErrorAction Stop }
		else { Update-Module -Name DupreeFunctions -RequiredVersion $DupreeFunctionsMinVersion -Force -ErrorAction Stop }
		$DupreeFunctionInstallSuccess = $true
	}
	catch { Write-Host "Failed to install 'DupreeFunctions' module from PSGallery!!! Error encountered is:`n`r`t$($Error[0])" -ForegroundColor Red ; $DupreeFunctionInstallSuccess = $false}
}
else { $DupreeFunctionInstallSuccess = $true } #>

#Make it pretty
function prompt {
	$path = (Get-Location).Path
	$vCenter = $global:DefaultVIServers.Name
	if (($vCenter -eq "") -or ($null -eq $vCenter)) { $vCenter = "NotConnected" }
	# $path = ""
	# $pathbits = ([string]$pwd).split("\", [System.StringSplitOptions]::RemoveEmptyEntries)
	# if($pathbits.length -eq 1) {
	# 	$path = $pathbits[0] + "\"
	# } else {
	# 	$path = $pathbits[$pathbits.length - 1]
	# }
	$userLocation = $env:username + '@' + [System.Environment]::UserDomainName + ' ' + $path
	$WindowTitle = $userLocation + ' ' + $vCenter
	$host.UI.RawUi.WindowTitle = $WindowTitle
	Write-Host($userLocation) -nonewline -foregroundcolor Green 

	Write-Host('>') -nonewline -foregroundcolor Green    
	return " "
}