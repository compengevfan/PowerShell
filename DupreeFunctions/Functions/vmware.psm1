Function Import-PowerCLI {
    Param(
    )
 
    if (!(Get-Module -Name VMware.VimAutomation.Core)) {
        write-host ("Adding PowerCLI...")
        Get-Module -Name VMware* -ListAvailable | Import-Module -Global
        write-host ("Loaded PowerCLI.")
    }
}

function Connect-vCenter {
    Param(
        [Parameter()] [string] $vCenter,
        [Parameter()] [PSCredential] $Credential
    )

    $ConnectedvCenter = $global:DefaultVIServers
    if ($ConnectedvCenter.Count -eq 1) {
        Write-Host "You are currently connected to $($ConnectedvCenter.Name)."
        $Response = Read-Host "Do you want to disconnect? (y/n; default 'n')"
      
        if ($Response -eq 'y')
        { Disconnect-VIServer -Confirm:$false -Force; $ConnectedvCenter = $global:DefaultVIServers }
    }
  
    if ($ConnectedvCenter.Count -eq 0) {
        if ((Test-Path "$githome\powershell\etc\vCenterDict.csv") -and ($null -eq $vCenter -or $vCenter -eq "")) {
            $vCenters = Import-Csv "$githome\powershell\etc\vCenterDict.csv" | Sort-Object FriendlyName

            $vCenter = (DriveMenu -Objects $vCenters -MenuColumn FriendlyName -SelectionText "Pick a vCenter" -ClearScreen $false).VCName
        }

        if ($null -eq $vCenter -or $vCenter -eq "") { $vCenter = Read-Host "Please provide the name of a vCenter server..." }
        do {
            if ($ConnectedvCenter.Count -eq 0 -or $null -eq $ConnectedvCenter) { Write-Host "Attempting to connect to vCenter server $vCenter" }

            #Set-PowerCLIConfiguration -invalidcertificateaction ignore -Confirm:$false | Out-Null

            if ($null -eq $Credential) { Connect-VIServer -Server $vCenter -Force | Out-Null }
            else { Connect-VIServer -Server $vCenter -Credential $Credential -Force | Out-Null }
      
            $ConnectedvCenter = $global:DefaultVIServers

            if ($ConnectedvCenter.Count -eq 0 -or $null -eq $ConnectedvCenter) { Write-Host "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
        } while ($ConnectedvCenter.Count -eq 0)
    }
}

function Show-vCenter {
    $ConnectedvCenter = $global:DefaultVIServers

    if ($ConnectedvCenter.Count -eq 1) {
        Write-Host "You are currently connected to $($ConnectedvCenter.Name)." -ForegroundColor Green
    }
    else {
        Write-Host "You are currently not connected to a vCenter Server." -ForegroundColor Yellow
    }
}

function Wait-Shutdown {
    while ($PowerState -eq "PoweredOn") {
        Start-Sleep 5
        $PowerState = (Get-VM $($LocalGoldCopy.Name)).PowerState
    }
}

Function Find-VmByAddress {
    <#  .Description
	    Find all VMs w/ a NIC w/ the given MAC address or IP address (by IP address relies on info returned from VMware Tools in the guest, so those must be installed).  Includes FindByIPWildcard, so that one can find VMs that approximate IP, like "10.0.0.*"
	    .Example
	    Get-VMByAddress -MAC 00:50:56:00:00:02
	    VMName        MacAddress
	    ------        ----------
	    dev0-server   00:50:56:00:00:02,00:50:56:00:00:04

	    Get VMs with given MAC address, return VM name and its MAC addresses
	    .Example
	    Get-VMByAddress -IP 10.37.31.120
	    VMName         IPAddr
	    ------         ------
	    dev0-server2   192.168.133.1,192.168.253.1,10.37.31.120,fe80::...

	    Get VMs with given IP as reported by Tools, return VM name and its IP addresses
	    .Example
	    Get-VMByAddress -AddressWildcard 10.0.0.*
	    VMName   IPAddr
	    ------   ------
	    someVM0  10.0.0.119,fe80::...
	    someVM2  10.0.0.138,fe80::...
	    ...

	    Get VMs matching the given wildcarded IP address
    #>

    [CmdletBinding(DefaultParametersetName = "FindByMac")]
    param (
        ## MAC address in question, if finding VM by MAC; expects address in format "00:50:56:83:00:69"
        [parameter(Mandatory = $true, ParameterSetName = "FindByMac")][string]$MacToFind_str,
        ## IP address in question, if finding VM by IP
        [parameter(Mandatory = $true, ParameterSetName = "FindByIP")][ValidateScript({ [bool][System.Net.IPAddress]::Parse($_) })][string]$IpToFind_str,
        ## wildcard string IP address (standard wildcards like "10.0.0.*"), if finding VM by approximate IP
        [parameter(Mandatory = $true, ParameterSetName = "FindByIPWildcard")][string]$AddressWildcard_str
    ) ## end param


    Process {
        Switch ($PsCmdlet.ParameterSetName) {
            "FindByMac" {
                ## return the some info for the VM(s) with the NIC w/ the given MAC
                Get-View -Viewtype VirtualMachine -Property Name, Config.Hardware.Device | Where-Object { $_.Config.Hardware.Device | Where-Object { ($_ -is [VMware.Vim.VirtualEthernetCard]) -and ($_.MacAddress -eq $MacToFind_str) } } | Select-Object @{n = "VMName"; e = { $_.Name } }, @{n = "MacAddress"; e = { ($_.Config.Hardware.Device | Where-Object { $_ -is [VMware.Vim.VirtualEthernetCard] } | ForEach-Object { $_.MacAddress } | Sort-Object) -join "," } }
                break;
            } ## end case
            { "FindByIp", "FindByIPWildcard" -contains $_ } {
                ## scriptblock to use for the Where clause in finding VMs
                $sblkFindByIP_WhereStatement = if ($PsCmdlet.ParameterSetName -eq "FindByIPWildcard") { { $_.IpAddress | Where-Object { $_ -like $AddressWildcard_str } } } else { { $_.IpAddress -contains $IpToFind_str } }
                ## return the .Net View object(s) for the VM(s) with the NIC(s) w/ the given IP
                Get-View -Viewtype VirtualMachine -Property Name, Guest.Net | Where-Object { $_.Guest.Net | Where-Object $sblkFindByIP_WhereStatement } | Select-Object @{n = "VMName"; e = { $_.Name } }, @{n = "IPAddr"; e = { ($_.Guest.Net | ForEach-Object { $_.IpAddress } | Sort-Object) -join "," } }
            } ## end case
        } ## end switch
    } ## end process
}

function Get-FolderByPath {
    <# .SYNOPSIS Retrieve folders by giving a path .DESCRIPTION The function will retrieve a folder by it's path. The path can contain any type of leave (folder or datacenter). .NOTES Author: Luc Dekens .PARAMETER Path The path to the folder. This is a required parameter. .PARAMETER Path The path to the folder. This is a required parameter. .PARAMETER Separator The character that is used to separate the leaves in the path. The default is '/' .EXAMPLE PS> Get-FolderByPath -Path "Folder1/Datacenter/Folder2"
.EXAMPLE
  PS> Get-FolderByPath -Path "Folder1>Folder2" -Separator '>'
#>
 
    param(
        [CmdletBinding()]
        [parameter(Mandatory = $true)]
        [System.String[]]${Path},
        [char]${Separator} = '/'
    )
 
    process {
        if ((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple") {
            $vcs = $defaultVIServers
        }
        else {
            $vcs = $defaultVIServers[0]
        }
 
        foreach ($vc in $vcs) {
            foreach ($strPath in $Path) {
                $root = Get-Folder -Name Datacenters -Server $vc
                $strPath.Split($Separator) | ForEach-Object {
                    $root = Get-Inventory -Name $_ -Location $root -Server $vc -NoRecursion
                    if ((Get-Inventory -Location $root -NoRecursion | Select-Object -ExpandProperty Name) -contains "vm") {
                        $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion
                    }
                }
                $root | Where-Object { $_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl] } | ForEach-Object {
                    Get-Folder -Name $_.Name -Location $root.Parent -NoRecursion -Server $vc
                }
            }
        }
    }
}

function Get-AlarmActionState {
    <#  
    .SYNOPSIS  Returns the state of Alarm actions.    
    .DESCRIPTION The function will return the state of the
      alarm actions on a vSphere entity or on the the entity
      and all its children
    .NOTES  Author:  Luc Dekens  
    .PARAMETER Entity
      The vSphere entity.
    .PARAMETER Recurse
      Switch that indicates if the state shall be reported for
      the entity alone or for the entity and all its children.
    .EXAMPLE
      PS> Get-AlarmActionState -Entity $cluster -Recurse:$true
    #>
     
    param(
        [CmdletBinding()]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$Entity,
        [switch]$Recurse = $false
    )
     
    process {
        $Entity = Get-Inventory -Id $Entity.Id
        if ($Recurse) {
            $objects = @($Entity)
            $objects += Get-Inventory -Location $Entity
        }
        else {
            $objects = $Entity
        }
     
        $objects |
        Select-Object Name,
        @{N = "Type"; E = { $_.GetType().Name.Replace("Impl", "").Replace("Wrapper", "") } },
        @{N = "Alarm actions enabled"; E = { $_.ExtensionData.alarmActionsEnabled } }
    }
}
    
function Set-AlarmActionState {
    <#  
    .SYNOPSIS  Enables or disables Alarm actions   
    .DESCRIPTION The function will enable or disable
      alarm actions on a vSphere entity itself or recursively
      on the entity and all its children.
    .NOTES  Author:  Luc Dekens  
    .PARAMETER Entity
      The vSphere entity.
    .PARAMETER Enabled
      Switch that indicates if the alarm actions should be
      enabled ($true) or disabled ($false)
    .PARAMETER Recurse
      Switch that indicates if the action shall be taken on the
      entity alone or on the entity and all its children.
    .EXAMPLE
      PS> Set-AlarmActionState -Entity $cluster -Enabled:$true
    #>
     
    param(
        [CmdletBinding()]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$Entity,
        [switch]$Enabled,
        [switch]$Recurse
    )
     
    begin {
        $alarmMgr = Get-View AlarmManager 
    }
     
    process {
        if ($Recurse) {
            $objects = @($Entity)
            $objects += Get-Inventory -Location $Entity
        }
        else {
            $objects = $Entity
        }
        $objects | ForEach-Object {
            $alarmMgr.EnableAlarmActions($_.Extensiondata.MoRef, $Enabled)
        }
    }
}