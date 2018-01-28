Function Check-PowerCLI
{
    Param(
    )

    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
        $PrevPath = Get-Location

	    write-host ("Adding PowerCLI...")
        if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts")
        {
            cd "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts"
	        .\Initialize-PowerCLIEnvironment.ps1
        }
        if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts")
        {
            cd "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts"
            .\Initialize-PowerCLIEnvironment.ps1
        }

        cd $PrevPath

	    write-host ("Loaded PowerCLI.")
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

Function DoLogging
{
    Param(
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
        Err
        {
            Write-Host -F Red $LogString
            if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Cloud-O-Mite Encountered an Error" -body $EmailBody }
        }
    }
}

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

Function Get-FileName
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $initialDirectory = Get-Location
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "JSON (*.json)| *.json"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
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