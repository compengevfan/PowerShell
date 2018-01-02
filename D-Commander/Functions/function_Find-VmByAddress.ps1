function Find-VmByAddress
{
    param (
	    ## MAC address in question, if finding VM by MAC; expects address in format "00:50:56:83:00:69"
	    [parameter(Mandatory=$true,ParameterSetName="FindByMac")][string]$MacToFind_str,
	    ## IP address in question, if finding VM by IP
	    [parameter(Mandatory=$true,ParameterSetName="FindByIP")][ValidateScript({[bool][System.Net.IPAddress]::Parse($_)})][string]$IpToFind_str,
	    ## wildcard string IP address (standard wildcards like "10.0.0.*"), if finding VM by approximate IP
	    [parameter(Mandatory=$true,ParameterSetName="FindByIPWildcard")][string]$AddressWildcard_str
    ) ## end param


    Process {
	    Switch ($PsCmdlet.ParameterSetName) {
		    "FindByMac" {
			    ## return the some info for the VM(s) with the NIC w/ the given MAC
			    Get-View -Viewtype VirtualMachine -Property Name, Config.Hardware.Device | Where-Object {$_.Config.Hardware.Device | Where-Object {($_ -is [VMware.Vim.VirtualEthernetCard]) -and ($_.MacAddress -eq $MacToFind_str)}} | select @{n="VMName"; e={$_.Name}},@{n="MacAddress"; e={($_.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualEthernetCard]} | %{$_.MacAddress} | sort) -join ","}}
			    break;
			    } ## end case
		    {"FindByIp","FindByIPWildcard" -contains $_} {
			    ## scriptblock to use for the Where clause in finding VMs
			    $sblkFindByIP_WhereStatement = if ($PsCmdlet.ParameterSetName -eq "FindByIPWildcard") {{$_.IpAddress | Where-Object {$_ -like $AddressWildcard_str}}} else {{$_.IpAddress -contains $IpToFind_str}}
			    ## return the .Net View object(s) for the VM(s) with the NIC(s) w/ the given IP
			    Get-View -Viewtype VirtualMachine -Property Name, Guest.Net | Where-Object {$_.Guest.Net | Where-Object $sblkFindByIP_WhereStatement} | Select @{n="VMName"; e={$_.Name}}, @{n="IPAddr"; e={($_.Guest.Net | %{$_.IpAddress} | sort) -join ","}}
		    } ## end case
	    } ## end switch
    } ## end process
}