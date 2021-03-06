<#
	.SYNOPSIS
		This Script allows you to disable certain IPv6 components in Windows 7 and Windows Server 2008.

	.DESCRIPTION
		This Script allows you to disable certain IPv6 components in Windows 7 and Windows Server 2008. The script requires PowerShell 2.0 and can be run remotely. The script isn't tested on Windows Vista but may work.

	.PARAMETER  ComputerName
		Computer where IPv6 components need to be disabled. Administrator access to the computer is required and remote registry must be accessible. If ComputerName isn't specified, the script will run against local computer.

	.PARAMETER  All
		Disable all IPv6 components, except the IPv6 loopback interface. This parameter is mutually exclusive to and can't be used with PrefixIPv4, NativeInterfaces, TunnelInterfaces or EnableLoopBackOnly.
	
	.PARAMETER  PrefixIPv4
		Use IPv4 instead of IPv6 in prefix policies. This parameter is mutually exclusive to and can't be used with All, NativeInterfaces, TunnelInterfaces or EnableLoopBackOnly.
		
	.PARAMETER  NativeInterfaces
		Disable native IPv6 interfaces. This parameter is mutually exclusive to and can't be used with All, PrefixIPv4, TunnelInterfaces or EnableLoopBackOnly.
		
	.PARAMETER  TunnelInterfaces
		Disable all tunnel IPv6 interfaces. This parameter is mutually exclusive to and can't be used with All, PrefixIPv4, NativeInterfaces or EnableLoopBackOnly.
	
	.PARAMETER  EnableLoopBackOnly
		Disable all IPv6 interfaces except for the IPv6 loopback interface.  This parameter is mutually exclusive to and can't be used with All, PrefixIPv4, NativeInterfaces or TunnelInterfaces.

	.EXAMPLE
		PS C:\> .\Disable-IPv6Components.ps1 -All

	.EXAMPLE
		PS C:\> .\Disable-IPv6Components.ps1 -ComputerName Server1 -TunnelInterfaces

	.LINK
		http://blogs.technet.com/b/bshukla/
		
	.LINK
		http://support.microsoft.com/kb/929852

#>
#Requires -Version 2.0

param 
(
	[String] $ComputerName = $Env:COMPUTERNAME,
	[switch] $All,
	[switch] [alias("IPv4")] $PrefixIPv4,
	[switch] [alias("Native")] $NativeInterfaces,
	[switch] [alias("Tunnel")] $TunnelInterfaces,
	[switch] [alias("LoopBack")] $EnableLoopBackOnly
)

$ErrMessage = "You can specify ONLY one of the following options - All, PrefixIPv4, NativeInterfaces, TunnelInterfaces, EnableLoopBackOnly."
$validation = $false

If (-not ($All -or $PrefixIPv4 -or $NativeInterfaces -or $TunnelInterfaces -or $EnableLoopBackOnly))
{
	Write-Error "You must specify atleast one of the following options - All, PrefixIPv4, NativeInterfaces, TunnelInterfaces, EnableLoopBackOnly."
	Get-Help $($MyInvocation.MyCommand.Path) -examples
	return
}

if ($All -and -not ($PrefixIPv4 -or $NativeInterfaces -or $TunnelInterfaces -or $EnableLoopBackOnly)) 
{
	$props = "{0:x}" -f 4294967295
	$validation = $true
	$propchanged = "disable all IPv6 components except the loopback interface."
}

if ($PrefixIPv4 -and -not ($All -or $NativeInterfaces -or $TunnelInterfaces -or $EnableLoopBackOnly)) 
{
	$props = "{0:x}" -f 32
	$validation = $true
	$propchanged = "use IPv4 instead of IPv6 prefix policies."
}


if ($NativeInterfaces -and -not ($PrefixIPv4 -or $All -or $TunnelInterfaces -or $EnableLoopBackOnly)) 
{
	$props = "{0:x}" -f 16
	$validation = $true
	$propchanged = "disable native IPv6 interfaces."
}


if ($TunnelInterfaces -and -not ($PrefixIPv4 -or $NativeInterfaces -or $All -or $EnableLoopBackOnly)) 
{
	$props = "{0:x}" -f 1
	$validation = $true
	$propchanged = "disable all tunnel IPv6 interfaces."
}


if ($EnableLoopBackOnly -and -not ($PrefixIPv4 -or $NativeInterfaces -or $TunnelInterfaces -or $All)) 
{
	$props = "{0:x}" -f 17
	$validation = $true
	$propchanged = "disable all IPv6 interfaces except for the IPv6 loopback interface."
}


If (-not $validation)
{
	Write-Error $ErrMessage
	return
}

try {
# Set Registry Key variables
$REG_KEY = "System\\CurrentControlSet\\Services\\TCPIP6\\Parameters"
$VALUE = 'DisabledComponents'

# Open remote registry
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName)
		
# Open the targeted remote registry key/subkey as read/write
$regKey = $reg.OpenSubKey($REG_KEY,$true)

# Create/Set DisabledComponents key and value
$regKey.Setvalue($VALUE, [Convert]::ToInt32($props,16), 'Dword')
		
# Make changes effective immediately
$regKey.Flush()
		
# Close registry key
$regKey.Close()
}
catch {
	Write-Error "An error occurred accessing registry. Please ensure registry on computer $ComputerName is accessible and PowerShell is launched with administrative permissions."
	$didcatch = $true
}
finally {
	If (-not $didcatch)
	{
		Write-Output "The Computer $ComputerName was set to $propchanged The changes will take effect after the computer $ComputerName is rebooted."
	}
}
