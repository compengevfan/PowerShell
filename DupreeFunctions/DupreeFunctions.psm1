Function Import-PowerCLI
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

function Connect-vCenter
{
  Param(
      [Parameter()] [string] $vCenter,
      [Parameter()] $vCenterCredential
  )

  $ConnectedvCenter = $global:DefaultVIServers
  if ($ConnectedvCenter.Count -eq 1)
  {
      Write-Host "You are currently connected to $($ConnectedvCenter.Name)."
      $Response = Read-Host "Do you want to disconnect? (y/n; default 'n')"
      
      if ($Response -eq 'y')
      { Disconnect-VIServer -Confirm:$false -Force; $ConnectedvCenter = $global:DefaultVIServers }
  }
  
  if ($ConnectedvCenter.Count -eq 0)
  {
    if ((Test-Path "$githome\powershell\etc\vCenterDict.csv") -and ($vCenter -eq $null -or $vCenter -eq ""))
    {
      $vCenters = Import-Csv "$githome\powershell\etc\vCenterDict.csv" | Sort-Object FriendlyName

      $vCenter = (DriveMenu -Objects $vCenters -MenuColumn FriendlyName -SelectionText "Pick a vCenter" -ClearScreen $false).VCName
    }

    if ($vCenter -eq $null -or $vCenter -eq "") { $vCenter = Read-Host "Please provide the name of a vCenter server..." }
    do
    {
      if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) { Write-Host "Attempting to connect to vCenter server $vCenter" }

      #Set-PowerCLIConfiguration -invalidcertificateaction ignore -Confirm:$false | Out-Null

      if ($vCenterCredential -eq $null) { Connect-VIServer -Server $vCenter -Force | Out-Null }
      else { Connect-VIServer -Server $vCenter -Credential $vCenterCredential -Force | Out-Null }
      
      $ConnectedvCenter = $global:DefaultVIServers

      if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) { Write-Host "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
    } while ($ConnectedvCenter.Count -eq 0)
  }
}

function Show-vCenter
{
  $ConnectedvCenter = $global:DefaultVIServers

  if ($ConnectedvCenter.Count -eq 1){
    Write-Host "You are currently connected to $($ConnectedvCenter.Name)." -ForegroundColor Green
  }
  else {
    Write-Host "You are currently not connected to a vCenter Server." -ForegroundColor Yellow
  }
}

function Wait-Shutdown
{
    while ($PowerState -eq "PoweredOn")
    {
        Start-Sleep 5
        $PowerState = (Get-VM $($LocalGoldCopy.Name)).PowerState
    }
}

Function ConvertToDN
{
    Param(
        [Parameter(Mandatory=$true)] [string] $Domain,
        [Parameter(Mandatory=$true)] [string] $OUPath
    )

    $DN = ""

    $OUPath.Split('/') | foreach { $DN = "OU=" + $_ + "," + $DN }
    $Domain.Split('.') | foreach { $DN = $DN + "DC=" + $_ + "," }

    $DN = $DN.Substring(0,$DN.Length - 1)

    return $DN
}

Function Find-VmByAddress
{
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

    [CmdletBinding(DefaultParametersetName="FindByMac")]
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

function Get-FolderByPath{
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
 
  process{
    if((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple"){
      $vcs = $defaultVIServers
    }
    else{
      $vcs = $defaultVIServers[0]
    }
 
    foreach($vc in $vcs){
      foreach($strPath in $Path){
        $root = Get-Folder -Name Datacenters -Server $vc
        $strPath.Split($Separator) | %{
          $root = Get-Inventory -Name $_ -Location $root -Server $vc -NoRecursion
          if((Get-Inventory -Location $root -NoRecursion | Select -ExpandProperty Name) -contains "vm"){
            $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion
          }
        }
        $root | where {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]}|%{
          Get-Folder -Name $_.Name -Location $root.Parent -NoRecursion -Server $vc
        }
      }
    }
  }
}

Function Convert-PhoneticAlphabet {
##### ** THIS SCRIPT IS PROVIDED WITHOUT WARRANTY, USE AT YOUR OWN RISK **

<#
.SYNOPSIS
    Converts an alphanumeric string into the NATO Phonetic Alphabet equivalent.

.DESCRIPTION
    The advanced function will convert an alphanumeric string into the NATO phonetic alphabet.
	
.PARAMETER String
    This is the default, required parameter. It is the string that the advanced function will convert.

.EXAMPLE
    Convert-TMNatoAlphabet -String '12abc3'
    This example will convert the string, 12abc3, to its NATO phonetic alphabet equivalent. It will return, "One Two Alpha Bravo Charlie Three."

.EXAMPLE
    Convert-TMNatoAlphabet -String '1p2h3-cc'
    This example will attempt to convert the string, 1p2h3-cc, to its NATO phonetic alphabet equivalent. Since it contains an invalid character (-), it will return, "String contained illegal character(s)."

.EXAMPLE
    Convert-TMNatoAlphabet '1ph3cc'
    This example will convert the string, 1ph3cc, to its NATO phonetic alphabet equivalent. It will return, "One Papa Hotel Three Charlie Charlie."

.NOTES
    NAME: Convert-TMNatoAlphabet
    AUTHOR: Tommy Maynard
    LASTEDIT: 08/21/2014
    VERSION 1.1
        -Changed seperate alpha and numeric hashes into one, alphanumeric hash (numbers are being stored as strings)
    VERSION 1.2
        -Edited the logic that handles the conversion (no need for If and nested If - Initial If handles a-z 0-9 check)
        -Added string cleanup inside If statement
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0)]
        [string]$String
    )

    Begin {
        Write-Verbose -Message 'Creating alphanumeric hash table'
        $Hash = @{'A'=' Alpha ';'B'=' Bravo ';'C'=' Charlie ';'D'=' Delta ';'E'=' Echo ';'F'=' Foxtrot ';'G'=' Golf ';'H'=' Hotel ';'I'=' India ';'J'=' Juliet ';'K'=' Kilo ';'L'=' Lima ';'M'=' Mike ';'N'=' November ';'O'=' Oscar ';'P'=' Papa ';'Q'=' Quebec ';'R'=' Romeo ';'S'=' Sierra ';'T'=' Tango ';'U'=' Uniform ';'V'=' Victory ';'W'=' Whiskey ';'X'=' X-ray ';'Y'=' Yankee ';'Z'=' Zulu ';'0'=' Zero ';'1'=' One ';'2'=' Two ';'3'=' Three ';'4'=' Four ';'5'=' Five ';'6'=' Six ';'7'=' Seven ';'8'=' Eight ';'9'=' Nine '}
    
    } # End Begin

    Process {
        Write-Verbose -Message 'Checking string for illegal charcters'
        If ($String -match '^[a-zA-Z0-9]+$') {
            Write-Verbose -Message 'String does not have any illegal characters'
            $String = $String.ToUpper()

            Write-Verbose -Message 'Creating converted string'
            For ($i = 0; $i -le $String.Length; $i++) {
                [string]$Character = $String[$i]
                $NewString += $Hash.Get_Item($Character)
            }

            Write-Verbose -Message 'Cleaning up converted string'
            $NewString = ($NewString.Trim()).Replace('  ',' ')
            Write-Output $NewString
        } Else {
            Write-Output -Verbose 'String contained illegal character(s).'
        }
    } # End Process
} # End Function

Function Get-FileName
{
    Param(
        [Parameter(Mandatory=$true)] [string] $Filter
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $initialDirectory = Get-Location
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "$Filter (*.$Filter)| *.$Filter"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

Function Invoke-Logging
{
    Param(
        [Parameter(Mandatory=$true)] [string] $ScriptStarted,
        [Parameter(Mandatory=$true)] [string] $ScriptName,
        [Parameter(Mandatory=$true)][ValidateSet("Succ","Info","Warn","Err")] [string] $LogType,
        [Parameter()] [string] $LogString
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$TimeStamp $LogString" | Out-File .\~Logs\"$ScriptName $ScriptStarted.log" -append

    Write-Host -F DarkGray "[" -NoNewLine
    Write-Host -F Green "*" -NoNewLine
    Write-Host -F DarkGray "] " -NoNewLine
    Switch ($LogType)
    {
        Succ { Write-Host -F Green $LogString }
        Info { Write-Host -F White $LogString }
        Warn { Write-Host -F Yellow $LogString }
        Err { Write-Host -F Red $LogString }
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
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$Entity,
    [switch]$Recurse = $false
  )
 
  process {
    $Entity = Get-Inventory -Id $Entity.Id
    if($Recurse){
      $objects = @($Entity)
      $objects += Get-Inventory -Location $Entity
    }
    else{
      $objects = $Entity
    }
 
    $objects |
    Select Name,
    @{N="Type";E={$_.GetType().Name.Replace("Impl","").Replace("Wrapper","")}},
    @{N="Alarm actions enabled";E={$_.ExtensionData.alarmActionsEnabled}}
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
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$Entity,
    [switch]$Enabled,
    [switch]$Recurse
  )
 
  begin{
    $alarmMgr = Get-View AlarmManager 
  }
 
  process{
    if($Recurse){
      $objects = @($Entity)
      $objects += Get-Inventory -Location $Entity
    }
    else{
      $objects = $Entity
    }
    $objects | %{
      $alarmMgr.EnableAlarmActions($_.Extensiondata.MoRef,$Enabled)
    }
  }
}

Function DriveMenu
{
    Param(
        [Parameter(Mandatory=$true)] $Objects,
        [Parameter(Mandatory=$true)] [string] $MenuColumn,
        [Parameter(Mandatory=$true)] [string] $SelectionText,
        [Parameter(Mandatory=$true)] [bool] $ClearScreen
    )

    if ($ClearScreen) { Clear-Host }

    $i = 1
    $Objects_In_Array = @()

    foreach ($Object in $Objects)
    {
        $Objects_In_Array += New-Object -Type PSObject -Property (@{
            Identifier = $i
            MenuData = ($Object).$MenuColumn
        })
        $i++
    }

    foreach ($Object_In_Array in $Objects_In_Array) { Write-Host $("`t"+$Object_In_Array.Identifier+". "+$Object_In_Array.MenuData) }

    $Selection = Read-Host $SelectionText

    $ArraySelection = $Objects_In_Array[$Selection -1]

    $ReturnObject = $Objects | Where-Object $MenuColumn -eq $ArraySelection.MenuData

    return $ReturnObject
}

Export-ModuleMember -Function *