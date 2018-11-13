[CmdletBinding()]
Param(
)

#
#Begin Functions
#
function RunPsexec ($CurrServer)
{
	$Status = G:\Jobs\psexec \\$CurrServer "C:\Program Files\QLogic Corporation\QConvergeConsoleCLI\qaucli" -pr fc -z -x -o "C:\Program Files\$CurrServer.xml"
	return $Status
}

function SendEmail ($BadServers)
{
	#$ToAddress = "TEAMEntCompute@fanatics.com"
	$ToAddress = "cdupree@fanatics.com"
	$FromAddress = "HBACheckJAX@fanatics.com"
	$Subject = "Improperly configured HBA's Found!"
	$SMTPServer = "smtp.ff.p10"
	$EmailBody = ("The following servers have HBA config issues:`n`n")
	
	foreach ($BadServer in $BadServers)
	{
		$EmailBody = $EmailBody + $BadServer + "`n"
	}
	
	$EmailBody = $EmailBody + "`nPlease correct before next SAN upgrade. Script should be run from JAX-TS001."
	
	Send-MailMessage -To $ToAddress -Subject $Subject -Body $EmailBody -SmtpServer $SMTPServer -From $FromAddress -Priority High
}
#
#End Funtions
#

#
#Begin Main Block
#

$BadServers = @()

Copy-Item "\\jxfq-ops-cls010.fanatics.corp\ServerList\Servers.csv" "G:\Jobs\QLogic" -Force

$Servers = Import-CSV G:\Jobs\QLogic\Servers.csv

foreach ($Server in $Servers)
{
	if ($Server.Name -like "JAX-*")
	{
		$CurrServer = $Server.Name + "." + $Server.Domain
		if (Test-Path -path "\\$CurrServer\c$\Program Files\QLogic Corporation\QConvergeConsoleCLI\qaucli.exe")
		{
			RunPsexec ($CurrServer)

			Move-Item "\\$CurrServer\c$\Program Files\$CurrServer.xml" "G:\Jobs\QLogic" -Force
		}
	}
}

$ServersToCheck = gci .\*.xml

foreach ($ServerToCheck in $ServersToCheck)
{
	$XMLData = [xml](get-content $ServerToCheck)
	$HBAs = $XMLData.Qlogic.HBA
	
	if ($HBAs.Count -gt 0)
	{
		foreach ($HBA in $HBAs)
		{
			if ($HBA.Param.ConnectionOption -ne 0 -or $HBA.Param.LoginRetryCount -lt 60 -or $HBA.Param.PortDownRetryCount -lt 60 -or $HBA.Param.LinkDownTimeout -lt 30 -and $BadServers -notcontains $ServerToCheck.BaseName)
			{
				$BadServers += $ServerToCheck.BaseName
			}
		}
	}
}

if ($BadServers.Count -gt 0)
{
	SendEmail($BadServers)
}
#
#End Main Block
#