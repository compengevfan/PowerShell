function Connect-vCenter
{
    Param(
        [Parameter()] [string] $vCenter
    )

    $ConnectedvCenter = $global:DefaultVIServers
    if ($ConnectedvCenter.Count -eq 0)
    {
        if ($vCenter -eq $null -or $vCenter -eq "") { $vCenter = Read-Host "Please provide the name of a vCenter server..." }
        do
        {
            if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) { Write-Host "Attempting to connect to vCenter server $vCenter" }
        
            Connect-VIServer $vCenter | Out-Null
            $ConnectedvCenter = $global:DefaultVIServers

            if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) { Write-Host "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
        } while ($ConnectedvCenter.Count -eq 0)
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

function Get-VmByMacAddress {
  <#
  .SYNOPSIS
    Retrieves the virtual machines with a certain MAC address on a vSphere server.
     
  .DESCRIPTION
    Retrieves the virtual machines with a certain MAC address on a vSphere server.
     
  .PARAMETER MacAddress
    Specify the MAC address of the virtual machines to search for.
     
  .EXAMPLE
    Get-VmByMacAddress -MacAddress 00:0c:29:1d:5c:ec,00:0c:29:af:41:5c
    Retrieves the virtual machines with MAC addresses 00:0c:29:1d:5c:ec and 00:0c:29:af:41:5c.
     
  .EXAMPLE
    "00:0c:29:1d:5c:ec","00:0c:29:af:41:5c" | Get-VmByMacAddress
    Retrieves the virtual machines with MAC addresses 00:0c:29:1d:5c:ec and 00:0c:29:af:41:5c.
     
  .COMPONENT
    VMware vSphere PowerCLI
     
  .NOTES
    Author:  Robert van den Nieuwendijk
    Date:    18-07-2011
    Version: 1.0
  #>
   
  [CmdletBinding()]
  param(
    [parameter(Mandatory = $true,
               ValueFromPipeline = $true,
               ValueFromPipelineByPropertyName = $true)]
    [string[]] $MacAddress
  )
   
  begin {
    # $Regex contains the regular expression of a valid MAC address
    $Regex = "^[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]$" 
   
    # Get all the virtual machines
    $VMsView = Get-View -ViewType VirtualMachine -Property Name,Guest.Net
  }
   
  process {
    ForEach ($Mac in $MacAddress) {
      # Check if the MAC Address has a valid format
      if ($Mac -notmatch $Regex) {
        Write-Error "$Mac is not a valid MAC address. The MAC address should be in the format 99:99:99:99:99:99."
      }
      else {    
        # Get all the virtual machines
        $VMsView | `
          ForEach-Object {
            $VMview = $_
            $VMView.Guest.Net | Where-Object {
              # Filter the virtual machines on Mac address
              $_.MacAddress -eq $Mac
            } | `
              Select-Object -property @{N="VM";E={$VMView.Name}},
                MacAddress,
                IpAddress,
                Connected
          }
      }
    }
  }
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
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $initialDirectory = Get-Location
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "JSON (*.json)| *.json"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

Function DoLogging
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
        Err
        {
            Write-Host -F Red $LogString
            if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Cloud-O-Mite Encountered an Error" -body $EmailBody }
        }
    }
}

Export-ModuleMember -Function *