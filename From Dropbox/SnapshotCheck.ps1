#########################
# BEGIN: User Variables #
#########################

# Log File location
$LogFile = "C:\Scripts\Snapshot.log"

# Virtual Centre server to connect to
$VCServer = "crifvc.criflending.com"

# Email parameters for emailing logfile results
# emailTo is a comma separated list of strings eg. "email1","email2"
$emailEnable = $true
$emailFrom = "CRIFVC@criflending.com"
$emailTo = "vmwaresupport@criflending.com"
$emailSubject = "VMware Snapshot Check"
$emailServer = "aspexchange.myappro.com"

#########################
#   END: User Variables #
#########################

###############################
# BEGIN: Function Definitions #
###############################

function Output-Data
{
<#
.SYNOPSIS       Outputs Data or messages in the desired method
.DESCRIPTION    This function is designed to use the $LogFile global variable to avoid
                having to specify the output file each time it is called.
                Data is output to the log file by default and optionally to the console as well.
.NOTES          Author:  Grant Brunton
.PARAMETER      Data:
                    The message or object to ouput to the log
.PARAMETER      ToHost:
                TH:
                    Optional switch to include displaying the output to the console
.EXAMPLE
                PS> Output-Data $object
.EXAMPLE
                PS> Output-Data "Message" -ToHost
#>

    [CmdletBinding()]
    Param
    (
        [parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [Object]$Data,
        [alias("TH")]
        [switch]$ToHost
    )
    
    Process
    {
        if ($ToHost) { $Data | fl }
        $Data | fl | Out-File $LogFile -Encoding ASCII -Append
    }
}

function Load-VMLibrary
{
<#
.SYNOPSIS       Loads VMware core modules and connects to VI Server
.DESCRIPTION    The function loads the VMware core modules required
                for processing VMware PowerCLI commands.
                This requires the PowerCLI modules to be installed.
                It will also connect to the VIServer ready for accepting commands.
.NOTES          Author:  Grant Brunton
.PARAMETER      VIServer:
                    The Virtual Centre Server to connect to.
                    The default is "VirtualCentre"
.PARAMETER      Credential:
                    A PSCredential object used to authenticate with the VIServer to connect to.
                    Credential objects can be created using the Get-Credential cmdlet
                    By default the logged on user credentials are used to authenticate.
.EXAMPLE
                PS> Load-VMLibrary
.EXAMPLE
                PS> Load-VMLibrary "server1"
.EXAMPLE
                PS> $cred = Get-Credential
                PS> Load-VMLibrary -VIServer "server1" -Credential $cred
.EXAMPLE
                PS> $cred = $host.ui.PromptForCredential("ESX/ESXi Credentials Required", "Please enter credentials to log into the ESX/ESXi host.", "", "")
                PS> "server1" | Load-VMLibrary -Credential $cred
#>

    [CmdletBinding()]
    Param
    (
        [parameter(ValueFromPipeline=$true,Position=0)]
        [String]$VIServer = "VirtualCentre",
        [object]$Credential = $null
        
    )
    
    Process
    {
        $vmwaretoolkit = Get-PSSnapin | where {$_.Name -eq "VMware.VimAutomation.Core"}

        if (!$vmwaretoolkit)
        {
            $vmwaretoolkit = Get-PSSnapin -registered | where {$_.Name -eq "VMware.VimAutomation.Core"}
            if ($vmwaretoolkit)
            {
                Add-PSSnapin "VMware.VimAutomation.Core"
                if (!$?) { Output-Data -TH "Failed to load VMware snapin. Ensure VMware vSphere PowerCLI is installed correctly." ; exit }
            }
            else
            {
                Output-Data -TH "Please install VMware vSphere PowerCLI to use this script."
                exit
            }
        }

        Set-PowerCLIConfiguration -DefaultVIServerMode Single -Confirm:$false > $null
        if ($Credential -ne $null)
        {
            if ($Credential.GetType().Name -ne "PSCredential")
            {
                Output-Data -TH "Invalid credential format supplied"
                exit
            }
            $VIServer = Connect-VIServer $VIServer -Credential $Credential
        }
        else
        {
            $VIServer = Connect-VIServer $VIServer
        }
        if (!$?) { Output-Data -TH "Failed to connect to VM host. Please ensure the correct VIServer is specified and you have correct logon credentials." ; exit }
    }
}

function Check-OrphanedData{
<#
.SYNOPSIS   Remove orphaned folders and VMDK files
.DESCRIPTION   The function searches orphaned folders and VMDK files
   on one or more datastores and reports its findings.
   Optionally the function removes  the orphaned folders   and VMDK files
.NOTES   Author:  Luc Dekens
         Modified by:  Grant Brunton
.PARAMETER Datastore
   One or more datastores.
   The default is to investigate all shared VMFS datastores
.PARAMETER Delete
   A switch that indicates if you want to remove the folders
   and VMDK files
.EXAMPLE
   PS> Remove-OrphanedData
.EXAMPLE
  PS> Get-Datastore ds* | Remove-OrphanedData
.EXAMPLE
  PS> Remove-OrphanedData -Datastore $ds -Delete
#>

  [CmdletBinding()]
  param(
      [parameter(ValueFromPipeline=$true)]
      [PSObject[]]$Datastore,
      [switch]$Delete
  )

  begin{
    $fldList = @{}
    $hdList = @{}

    $fileMgr = Get-View FileManager
  }

  process{
    if(!$Datastore){
      $Datastore = Get-Datastore
    }
    foreach($ds in $Datastore){
      if($ds.GetType().Name -eq "String"){
        $ds = Get-Datastore -Name $ds
      }
      if($ds.Type -eq "VMFS" -and $ds.ExtensionData.Summary.MultipleHostAccess){
        Get-VM -Datastore $ds | %{
          $_.Extensiondata.LayoutEx.File | where{"diskDescriptor","diskExtent" -contains $_.Type} | %{
            $fldList[$_.Name.Split('/')[0]] = $_.Name
            $hdList[$_.Name] = $_.Name
          }
        }
        Get-Template | where {$_.DatastoreIdList -contains $ds.Id} | %{
          $_.Extensiondata.LayoutEx.File | where{"diskDescriptor","diskExtent" -contains $_.Type} | %{
            $fldList[$_.Name.Split('/')[0]] = $_.Name
            $hdList[$_.Name] = $_.Name
          }
        }

        $dc = $ds.Datacenter.Extensiondata

        $flags = New-Object VMware.Vim.FileQueryFlags
        $flags.FileSize = $true
        $flags.FileType = $true

        $disk = New-Object VMware.Vim.VmDiskFileQuery
        $disk.details = New-Object VMware.Vim.VmDiskFileQueryFlags
        $disk.details.capacityKb = $true
        $disk.details.diskExtents = $true
        $disk.details.diskType = $true
        $disk.details.thin = $true

        $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
        $searchSpec.details = $flags
        $searchSpec.Query += $disk
        $searchSpec.sortFoldersFirst = $true

        $dsBrowser = Get-View $ds.ExtensionData.browser
        $rootPath = "[" + $ds.Name + "]"
        $searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec)
        foreach($folder in $searchResult){
          if($fldList.ContainsKey($folder.FolderPath.TrimEnd('/'))){
            foreach ($file in $folder.File){
              if(!$hdList.ContainsKey($folder.FolderPath + $file.Path)){
                $obj = New-Object PSObject -Property @{
                  Datastore = $ds.Name
                  Folder = $folder.FolderPath
                  FileName = $file.Path
                  Size = $file.FileSize
                  #CapacityKB = $file.CapacityKb
                  #Thin = $file.Thin
                  #Extents = [string]::Join(',',($file.DiskExtents | %{$_}))
                  Problem = "Orphaned file"
                }
                Output-data $obj
                if($Delete){
                  $dsBrowser.DeleteFile($folder.FolderPath + $file.Path)
                }
              }
            }
          }
          elseif($folder.File | where {"cos.vmdk","esxconsole.vmdk" -notcontains $_.Path}){
            $obj = New-Object PSObject -Property @{
              Datastore = $ds.Name
              Folder = $folder.FolderPath
              Problem = "Orphaned folder"
            }
            Output-data $obj
            if($Delete){
              $fileMgr.DeleteDatastoreFile($folder.FolderPath,$dc.MoRef)
            }
          }
        }
      }
    }
  }
}

function Check-Snapshot
{
<#
.SYNOPSIS       Checks VM guests for invalid snapshot images
.DESCRIPTION    This function checks VM guests to see if their harddisks are pointing to snapshot files.
                If they are it reports a detected problem if there are no snapshots listed for the guest
                or if a Consolidate Helper snapshot exists for the guest.
                A Consolidate Helper snapshot is usually created by a VCB type backup process and can be left behind
                if a snapshot removal process failed or the datastore ran out of room.
                If the Consolidate Helper snapshot appears by itself this is an indicator of a failed process.
                If the Consolidate Helper exists with other snapshots it may still be in the middle of the
                removal process.
.NOTES          Author:  Grant Brunton
.PARAMETER      VMGuest:
                    Can be an array or a single VM guest to check.
                    Input should be either the VM object or a string of the VM name.
                    By default all VM guests are checked.
.EXAMPLE
                PS> Check-Snapshot
.EXAMPLE
                PS> Check-Snapshot [-VMGuest] "vmguest"
.EXAMPLE
                PS> $vm = Get-VM "vmguest"
                PS> $vm | Check-Snapshot
#>

    [CmdletBinding()]
    Param
    (
        [parameter(ValueFromPipeline=$true, Position=0)]
        [PSObject]$VMGuest
    )
    
    Process
    {
        if(!$VMGuest)
        {
          $VMGuest = Get-VM
        }
        
        foreach($vm in $VMGuest)
        {
            if($vm.GetType().Name -eq "String")
            {
                $vm = Get-VM -Name $vm
            }
        	
            $vm | Get-HardDisk | %{
        		if ($_.Filename -match ".*-[0-9]{6}.vmdk")
                {
                    $obj = $null
                    if (!(Get-Snapshot $vm))
                    {
                        $obj = New-Object PSObject -Property @{
                          VMName = $vm.Name
                          VMHost = $vm.VMHost
                          Problem = "Missing Snapshot from Snapshot Manager"
                        }
                    }
                    elseif (Get-Snapshot $vm)
                    {
                        if (@(Get-Snapshot $vm).Length -eq 1)
                        {
                            $obj = New-Object PSObject -Property @{
                              VMName = $vm.Name
                              VMHost = $vm.VMHost
                              Problem = "Consolidate Helper exists for VM with no snapshots"
                            }
                        } else {
                            $obj = New-Object PSObject -Property @{
                              VMName = $vm.Name
                              VMHost = $vm.VMHost
                              Problem = "Consolidate Helper exists for VM but has snapshots"
                            }
                        }
                    }
                    
                    if ($obj -ne $null) { Output-Data $obj }
                    Continue
                }
            }
        }
    }
}

###############################
#   END: Function Definitions #
###############################

####################
# BEGIN: MAIN CODE #
####################

if (Test-Path $LogFile) { del $LogFile }
Load-VMLibrary $VCServer

Check-Snapshot
#Check-OrphanedData

if ($emailEnable -and (Test-Path $LogFile))
{
    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject $emailSubject -body (Get-Content $LogFile | Out-String)
}

####################
#   END: MAIN CODE #
####################
