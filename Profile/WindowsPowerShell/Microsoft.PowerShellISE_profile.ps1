#Check for Github environment variable
if ($env:githubhome) { $githubhome = $env:githubhome; Write-Host "Github path found." -ForegroundColor Green }
else { Write-Host "Github path NOT found." -ForegroundColor Yellow}

#Check for Git environment variable
if ($env:githome) { $githome = $env:githome; Write-Host "Git path found." -ForegroundColor Green }
else { Write-Host "Git path NOT found." -ForegroundColor Yellow}

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

# if (!(Get-Module -Name DupreeFunctions) -and $DupreeFunctionInstallSuccess) { Write-Host "DupreeFunctions Installed and up to date...Importing..." -ForegroundColor Green; Import-Module DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion }

if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available." -ForegroundColor Yellow }
elseif (!(Get-Module -Name DupreeFunctions)) {
	Write-Host "Importing DupreeFunctions..."
	Import-Module DupreeFunctions
	Write-Host "Creating Alias for 'Connect-vCenter' function..."
	Set-Alias -Name cvc -Value Connect-vCenter
}
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  
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