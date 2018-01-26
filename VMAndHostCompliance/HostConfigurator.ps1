[CmdletBinding()]
Param(
    [Parameter()] $vCenter = "iad-vc001.fanatics.corp",
    [Parameter()] $SendEmail = $true
)

##################
#System Variables
##################
$ErrorActionPreference = "SilentlyContinue"
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false

#Import functions
. .\Functions\function_DoLogging
. .\Functions\function_Check-PowerCLI.ps1

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "Cloud-O-MITE@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }

Check-PowerCLI

#If not connected to a vCenter, connect.
$ConnectedvCenter = $global:DefaultVIServers
if ($ConnectedvCenter.Count -eq 0)
{
    do
    {
        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) { DoLogging -LogType Info -LogString "Attempting to connect to vCenter server $vCenter..." }
        
        Connect-VIServer $vCenter | Out-Null
        $ConnectedvCenter = $global:DefaultVIServers

        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null){ DoLogging -LogType Warn -LogString "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
    } while ($ConnectedvCenter.Count -eq 0)
}

