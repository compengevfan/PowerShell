#Display .NET Versions Installed
Write-Host ".NET version installed: " -NoNewline
$dotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release
switch ($dotNetVersion) {
    378389 { Write-Host "4.5" }
    {($_ -eq 378675) -or ($_ -eq 378758)} { Write-Host "4.5.1" }
    379893 { Write-Host "4.5.2" }
    {($_ -eq 393295) -or ($_ -eq 393297)} { Write-Host "4.6" }
    {($_ -eq 394254) -or ($_ -eq 394271)} { Write-Host "4.6.1" }
    {($_ -eq 394802) -or ($_ -eq 394806)} { Write-Host "4.6.2" }
    {($_ -eq 460798) -or ($_ -eq 460805)} { Write-Host "4.7" }
    {($_ -eq 461308) -or ($_ -eq 461310)} { Write-Host "4.7.1" }
    {($_ -eq 461808) -or ($_ -eq 461814)} { Write-Host "4.7.2" }
    {($_ -eq 528040) -or ($_ -eq 528372) -or ($_ -eq 528049)} { Write-Host "4.8" }
    Default { Write-Host "Unknown build $dotNetVersion found."}
}

#Display PowerShell Version
Write-Host "`nPowerShell Version Installed:"
$PSVersionTable.PSVersion

#Check for Github environment variable
if ($env:githubhome) { $githubhome = $env:githubhome; Write-Host "`nGithub path found." -ForegroundColor Green }
else { Write-Host "`nGithub path NOT found." -ForegroundColor Yellow}

#Check for Git environment variable
if ($env:githome) { $githome = $env:githome; Write-Host "Git path found." -ForegroundColor Green }
else { Write-Host "Git path NOT found." -ForegroundColor Yellow}

#Check for Dropbox environment variable
if ($env:dropboxhome) { $dropboxhome = $env:dropboxhome; Write-Host "Dropbox path found." -ForegroundColor Green }
else { Write-Host "Dropbox path NOT found." -ForegroundColor Yellow}

# Write-Host "Checking DupreeFunctions module available and latest version..."
# $DupreeFunctionsMinVersion = (Find-Module DupreeFunctions).Version
# if (!(Get-InstalledModule -Name DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion -ErrorAction SilentlyContinue))
# {
# 	try 
# 	{
# 		if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Install-Module -Name DupreeFunctions -Scope CurrentUser -Force -ErrorAction Stop }
# 		else { Update-Module -Name DupreeFunctions -RequiredVersion $DupreeFunctionsMinVersion -Force -ErrorAction Stop }
# 		$DupreeFunctionInstallSuccess = $true
# 	}
# 	catch { Write-Host "Failed to install 'DupreeFunctions' module from PSGallery!!! Error encountered is:`n`r`t$($Error[0])" -ForegroundColor Red ; $DupreeFunctionInstallSuccess = $false}
# }
# else { $DupreeFunctionInstallSuccess = $true }

# if (!(Get-Module -Name DupreeFunctions) -and $DupreeFunctionInstallSuccess)
# {
# 	Write-Host "DupreeFunctions Installed and up to date...Importing..." -ForegroundColor Green
# 	Import-Module DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion
# }

if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available." -ForegroundColor Yellow }
elseif (!(Get-Module -Name DupreeFunctions)) {
	Write-Host "Importing DupreeFunctions..."
	Import-Module DupreeFunctions
	Write-Host "Creating Alias for 'Connect-vCenter' function..."
	Set-Alias -Name cvc -Value Connect-vCenter
	Write-Host "Creating Alias for 'Show-vCenter' function..."
	Set-Alias -Name svc -Value Show-vCenter
}
  
################
#Make it pretty#
################
function prompt {
	$path = ""
	$pathbits = ([string]$pwd).split("\", [System.StringSplitOptions]::RemoveEmptyEntries)
	if($pathbits.length -eq 1) {
		$path = $pathbits[0] + "\"
	} else {
		$path = $pathbits[$pathbits.length - 1]
	}
	$userLocation = $env:username + '@' + [System.Environment]::UserDomainName + ' ' + $path
	$host.UI.RawUi.WindowTitle = $userLocation
    Write-Host($userLocation) -nonewline -foregroundcolor Green 

	Write-Host('>') -nonewline -foregroundcolor Green    
	return " "
}