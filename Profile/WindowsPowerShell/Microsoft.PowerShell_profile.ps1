# Function Check-PowerCLI
# {
#     Param(
#     )
  
#     if (!(Get-Module -Name VMware.VimAutomation.Core))
#     {
#         write-host ("Adding PowerCLI...")
#         Get-Module -Name VMware* -ListAvailable | Import-Module -Global
#         write-host ("Loaded PowerCLI.")
#     }
# }

#Check for Github environment variable
if ($env:githubhome) { $githubhome = $env:githubhome; Write-Host "Github path Found." }

#Check for Git environment variable
if ($env:githome) { $githome = $env:githome; Write-Host "Git path Found." }

if ($(Get-WmiObject Win32_ComputerSystem).Domain -eq "evorigin.com")
{
	$DupreeFunctionsMinVersion = (Find-Module DupreeFunctions).Version
	if (!(Get-InstalledModule -Name DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion -ErrorAction SilentlyContinue))
	{
		try 
		{
			if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Install-Module -Name DupreeFunctions -Scope CurrentUser -Force -ErrorAction Stop }
			else { Update-Module -Name DupreeFunctions -RequiredVersion $DupreeFunctionsMinVersion -Force -ErrorAction Stop }
		}
		catch { Write-Host "Failed to install 'DupreeFunctions' module from PSGallery!!! Error encountered is:`n`r`t$($Error[0])`n`rScript exiting!!!" -ForegroundColor Red ; exit }
	}

	if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion }
}
# if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
# if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
# if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  
# Check-PowerCLI

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