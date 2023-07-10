Function Import-PowerCLI {
    [CmdletBinding()]
    Param(
    )
 
    if (!(Get-Module -Name VMware.VimAutomation.Core)) {
        write-host ("Adding PowerCLI...")
        Get-Module -Name VMware* -ListAvailable | Import-Module -Global
        write-host ("Loaded PowerCLI.")
    }
}

function Connect-vCenter {
    [CmdletBinding()]
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
    [CmdletBinding()]
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

Function Invoke-DrainHost {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)] [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$VMHost
    )

    $ErrorActionPreference = "Stop"

    $ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
    $ScriptName = $MyInvocation.MyCommand.Name

    # $LoggingSuccSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Succ"}
    $LoggingInfoSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Info" }
    # $LoggingWarnSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Warn"}
    # $LoggingErrSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Err"}

    try {
        $Cluster = $VMHost | Get-Cluster

        if ($($Cluster.DrsEnabled)) {
            Invoke-Logging @LoggingInfoSplat -LogString "Storing current cluster DRS Automation level."
            $Stored_DRS_Level = $Cluster.DrsAutomationLevel
            Invoke-Logging @LoggingInfoSplat -LogString "Setting DRS Automation level to manual."
            Set-Cluster -Cluster $Cluster -DrsAutomationLevel Manual -Confirm:$false | Out-Null
        }
    
        $VmsToMigrate = $VMHost | Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" }
        $VmsToMigrateCount = $VmsToMigrate.Count
        $VMc = 1
    
        foreach ($VmToMigrate in $VmsToMigrate) {
            # Write-Host "Determining host to migrate to."
            Invoke-Logging @LoggingInfoSplat -LogString "Determining host to migrate to."
            $ClusterHosts = $Cluster | Get-VMHost | Where-Object { $_.ConnectionState -eq "Connected" }
            $TargetHost = $ClusterHosts | Where-Object { $_ -ne $VMHost } | Sort-Object MemoryUsageGB | Select-Object -First 1
    
            # Write-Host "Moving VM $($VmToMigrate.Name) ($VMc of $VmsToMigrateCount) to $($TargetHost.Name)."
            Invoke-Logging @LoggingInfoSplat -LogString "Moving VM $($VmToMigrate.Name) ($VMc of $VmsToMigrateCount) to $($TargetHost.Name)."
            Move-VM -VM $VmToMigrate -Destination $TargetHost | Out-Null
    
            $VMc++
            Start-Sleep 5
        }
    
        # Write-Host "Setting cluster DRS to 'FullyAutomated'."
        Invoke-Logging @LoggingInfoSplat -LogString "Setting cluster DRS to 'FullyAutomated'."
        Set-Cluster -Cluster $Cluster -DrsAutomationLevel FullyAutomated -Confirm:$false | Out-Null
    
        # Write-Host "Verifying host is empty and setting to MM."
        Invoke-Logging @LoggingInfoSplat -LogString "Verifying host is empty and setting to MM."
        $Check = $VMHost | Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" }
        if ($null -eq $Check) { Set-VMHost -VMHost $VMHost -State Maintenance -Evacuate:$true -Confirm:$false | Out-Null }
        else { Invoke-Logging @LoggingErrSplat -LogString "Host did not completely drain. Please check VMs left on the host for VMotion errors, resolve and run the script again."; throw "Host did not completely drain. Please check VMs left on the host for VMotion errors, resolve and run the script again." }
    
        #Waiting for vCenter to do stuff
        Start-Sleep 30

        # Write-Host "Setting DRS mode to pre-script setting."
        Invoke-Logging @LoggingInfoSplat -LogString "Setting DRS mode to pre-script setting."
        Set-Cluster -Cluster $Cluster -DrsAutomationLevel $Stored_DRS_Level -Confirm:$false | Out-Null
    }
    catch {
        throw
    }
}

Function Invoke-PatchESXHost {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)] [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$HostToPatch,
        [Parameter()][ValidateSet("DRS", "DrainHost")] [string]$EvacType = "DrainHost",
        [bool]$AutoExitMm = $false,
        [string]$emailTo = ([DC.Automation]::TeamEmail)
    )

    $ErrorActionPreference = "Stop"

    $ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
    $ScriptName = $MyInvocation.MyCommand.Name

    $LoggingSuccSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Succ" }
    $LoggingInfoSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Info" }
    $LoggingWarnSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Warn" }
    $LoggingErrSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Err" }

    try {
        #Obtain a count of host datastores before applying updates
        $DsCountStart = ($HostToPatch | Get-Datastore).Count
        #Write-Host "Scanning $($HostToPatch.Name) baselines."
        Invoke-Logging $LoggingInfoSplat -LogString "Scanning $($HostToPatch.Name) baselines."
        Scan-Inventory -Entity $HostToPatch.Name

        #Write-Host "Determining if there are non-compliant baselines"
        Invoke-Logging $LoggingInfoSplat -LogString "Determining if there are non-compliant baselines"
        $NcBaselines = Get-Compliance -Entity $HostToPatch.Name -ComplianceStatus NotCompliant

        if ($null -eq $NcBaselines) { Invoke-Logging $LoggingSuccSplat -LogString "Host is already compliant with all applied baselines." }
        else {
            switch ($EvacType) {
                "DRS" { 
                    #Write-Host "Putting host in MM using DRS."
                    Invoke-Logging $LoggingInfoSplat -LogString "Putting host in MM using DRS."
                    Set-VMHost -VMHost $HostToPatch -State Maintenance -Evacuate:$true -Confirm:$false
                }
                "DrainHost" { 
                    #Write-Host "Putting host in MM using DrainHost Function."
                    Invoke-Logging $LoggingInfoSplat -LogString "Putting host in MM using DrainHost Function."
                    Invoke-DrainHost -VMHost $HostToPatch
                }
                Default {}
            }
    
            #Verify host is in MM
            # Write-Host "Verifying host is in MM."
            Invoke-Logging $LoggingInfoSplat -LogString "Verifying host is in MM."
            if ((Get-VMHost $HostToPatch).ConnectionState -ne "Maintenance") { Throw "$($HostToPatch.Name) is not in MM." }
    
            # Write-Host "Staging non-compliant baselines."
            Invoke-Logging $LoggingInfoSplat -LogString "Staging baselines."
            $Baselines = Get-PatchBaseline -Entity $HostToPatch -Inherit
            Copy-Patch -Entity $HostToPatch -Baseline $Baselines
            Invoke-Logging $LoggingInfoSplat -LogString "Remediating baselines: `r`n`t$($Baselines.Name -join "`n`t")"
            Remediate-Inventory -Entity $HostToPatch -Baseline $Baselines -ClusterDisableDistributedPowerManagement:$true -Confirm:$false -ErrorAction "Ignore"
    
            #Waiting for 10 successful pings
            # Write-Host "Performing ping checks."
            Invoke-Logging $LoggingInfoSplat -LogString "Performing ping checks."
            $PingCheck = 0
            while ($PingCheck -lt 10) {
                $PingCheck += 1
                if (!(Test-Connection -ComputerName $HostToPatch.Name -Count 1 -Quiet)) { Invoke-Logging @LoggingErrSplat -LogString "Post patch ping checks failed for $($HostToPatch.Name)"; throw "Post patch ping checks failed for $($HostToPatch.Name)" }
                Start-Sleep 3
            }
            
            #Rescan host and verify compliance
            # Write-Host "Rescanning $($HostToPatch.Name) baselines."
            Invoke-Logging $LoggingInfoSplat -LogString "Rescanning $($HostToPatch.Name) baselines."
            Scan-Inventory -Entity $HostToPatch.Name
            # Write-Host "Determining if there are non-compliant baselines"
            Invoke-Logging $LoggingInfoSplat -LogString "Determining if there are non-compliant baselines"
            $PostNcBaselines = Get-Compliance -Entity $HostToPatch.Name -ComplianceStatus NotCompliant
            if ($null -ne $PostNcBaselines) { Invoke-Logging $LoggingWarnSplat -LogString "Patching was attempted on $($HostToPatch.Name) but there are still non-compliant baselines." }
    
            #Verify datastore count matches pre-upgrade count
            Invoke-Logging $LoggingInfoSplat -LogString "Verifying datastore count matches pre-upgrade count."
            $DsCountEnd = ($HostToPatch | Get-Datastore).Count
            if ($DsCountStart -ne $DsCountEnd) { Invoke-Logging @LoggingErrSplat -LogString "Post upgrade datastore count on $($HostToPatch.Name) does not match the pre upgrade count"; throw "Post upgrade datastore count on $($HostToPatch.Name) does not match the pre upgrade count" }
    
            if ($AutoExitMm) {
                Invoke-Logging $LoggingInfoSplat -LogString "$($HostToPatch.Name) exiting Maintenance Mode."
                Set-VMHost -VMHost $HostToPatch -State Connected -Confirm:$false | Out-Null
            }
    
            # Write-Host "Sending success message."
            Invoke-Logging $LoggingSuccSplat -LogString "$($HostToPatch.Name) was successfully patched. Baselines installed: `r`n`t$($Baselines.Name -join "`n`t")"
        }
    }
    catch {
        # Write-Host "Sending failure message."
        Invoke-Logging $LoggingErrSplat -LogString "Attempt to patch $($HostToPatch.Name) failed. The error encountered was:`r`n$($_.Exception.Message)`n$($_.ScriptStackTrace)"
        Invoke-SendEmail -Subject "Host Patch Error" -EmailBody "Attempt to patch $($HostToPatch.Name) failed. The error encountered was:`r`n$($_.Exception.Message)`n$($_.ScriptStackTrace)"
        throw
    }
}

Function Invoke-PatchESXCluster {
    [cmdletbinding()]
    param (
        [Parameter()] [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]$ClusterToPatch,
        [Parameter()][ValidateSet("DRS", "DrainHost")] [string]$EvacType = "DrainHost",
        [string]$emailTo = ([DC.Automation]::TeamEmail)
    )

    $ErrorActionPreference = "Stop"

    $ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
    $ScriptName = $MyInvocation.MyCommand.Name

    $LoggingSuccSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Succ" }
    $LoggingInfoSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Info" }
    # $LoggingWarnSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Warn"}
    # $LoggingErrSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Err"}

    try {
        if ($null -eq $ClusterToPatch) {
            $Clusters = Get-Cluster | Sort-Object Name
            $ClusterToPatch = Invoke-Menu -Objects $Clusters -MenuColumn "Name" -SelectionText "Please select a cluster for ESX host upgrades" -ClearScreen:$true
        }

        $AreYouSure = Read-Host "Are you sure you want to apply ESX updates to the hosts in cluster $ClusterToPatch (You must respond with 'yes' to continue)?"
        if ($AreYouSure -ne "yes") { Write-Host "You did not respond with 'yes'." }
        else {
            # Write-Host "Getting all the hosts in the cluster sorted by Name."
            Invoke-Logging $LoggingInfoSplat -LogString "Getting all the hosts in the cluster sorted by Name."

            $ClusterHosts = $ClusterToPatch | Get-VMHost | Sort-Object Name

            foreach ($ClusterHost in $ClusterHosts) {
                Invoke-Logging $LoggingInfoSplat -LogString "Calling patch host function for $($ClusterHost.Name)"
                Invoke-PatchESXHost -HostToPatch $ClusterHost -EvacType $EvacType -AutoExitMm:$true
            }
            Invoke-Logging $LoggingSuccSplat -LogString "$($ClusterToPatch.Name) patch process compelete. Check email for server patch failures."
            Invoke-SendEmail -Subject "Cluster Patch Success" -EmailBody "$($ClusterToPatch.Name) was successfully patched."
        }
    }
    catch {
        throw
    }
}