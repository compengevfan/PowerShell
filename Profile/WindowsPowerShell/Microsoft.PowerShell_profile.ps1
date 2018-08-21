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
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  
Check-PowerCLI

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