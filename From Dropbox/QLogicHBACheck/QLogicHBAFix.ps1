[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True)]
   [string]$ServerName
)

#
#Begin Functions
#

function FixCO ($Identifier)
{
	$Fix = G:\Jobs\psexec \\$ServerName "C:\Program Files\QLogic Corporation\QConvergeConsoleCLI\qaucli" -pr fc -n $Identifier ConnectionOption 0
	return $Fix
}

function FixLRC ($Identifier, $ServerName)
{
	$Fix = G:\Jobs\psexec \\$ServerName "C:\Program Files\QLogic Corporation\QConvergeConsoleCLI\qaucli" -pr fc -n $Identifier LoginRetryCount 60
	return $Fix
}

function FixPDRC ($Identifier, $ServerName)
{
	$Fix = G:\Jobs\psexec \\$ServerName "C:\Program Files\QLogic Corporation\QConvergeConsoleCLI\qaucli" -pr fc -n $Identifier PortDownRetryCount 60
	return $Fix
}

function FixLDT ($Identifier, $ServerName)
{
	$Fix = G:\Jobs\psexec \\$ServerName "C:\Program Files\QLogic Corporation\QConvergeConsoleCLI\qaucli" -pr fc -n $Identifier LinkDownTimeout 30
	return $Fix
}

#
#End Funtions
#

#
#Begin Main Block
#

$XMLData = [xml](get-content .\$ServerName.xml)
$HBAs = $XMLData.Qlogic.HBA

foreach ($HBA in $HBAs)
{
	$Identifier = $HBA.HBA.WWPN
	if ([int]$HBA.Param.ConnectionOption -ne 0)
	{
		FixCO $Identifier $ServerName
	}
	
	if ([int]$HBA.Param.LoginRetryCount -lt 60)
	{
		FixLRC $Identifier $ServerName
	}
	
	if ([int]$HBA.Param.PortDownRetryCount -lt 60)
	{
		FixPDRC $Identifier $ServerName
	}
	
	if ([int]$HBA.Param.LinkDownTimeout -lt 30)
	{
		FixLDT $Identifier $ServerName
	}
}

#
#End Main Block
#