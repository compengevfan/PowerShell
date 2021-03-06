<# Provision_SR.ps1 

  Usage .\Provision_SR.ps1 SRxxxxx.csv

#>

Param ( $Csv )

<# Global Variables #>
#Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0
$Version = "2.4.3"
$BuildDate = "2013-08-15"
$motd = "`"Cloud-O-MITE!`""
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

<# Check PowerCLI Build #>
if ( !( (Get-PowerCLIVersion).Build -ge "1012425" ) ) { Write-Error "PowerCLI Build is not 1012425 or Higher" }

$VMs = Import-Csv $Csv

$StartTime          = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$InputFile          = Get-ChildItem $csv 
$LogFolder          = "C:\Temp\Logs\"
$LogSubFolder       =  $InputFile.Name.Split(".")[0] + "_" + $StartTime
New-Item            -Path $LogFolder -Name  $LogSubFolder -Type Directory | Out-Null
$LogFolder          += $LogSubFolder + "\"
$LogFile            = $InputFile.Name.Split(".")[0] + "_" + $StartTime + ".log"
$LogFileCsv         = $InputFile.Name.Split(".")[0] + "_" + $StartTime + ".csv"
$LogFileCustSpec    = $InputFile.Name.Split(".")[0] + "_" + $StartTime + "_CustSpec_" + ".xml"
$LogFileCustSpecNic = $InputFile.Name.Split(".")[0] + "_" + $StartTime + "_CustSpecNic_" + ".xml"
$NewLine            = ""
Copy-Item $InputFile $LogFolder$LogFileCsv

$UserName       = [Environment]::UserName
$UserDomainName = [Environment]::UserDomainName
$MachineName    = [Environment]::MachineName

$FreeSpaceGB = 75 # Minimum Datastore FreeSpaceGB after provision

$HotAddGuestList = "rhel6_64Guest",
                   "windows8Server64Guest",
                   "windows7_64Guest",
                   "windows8_64Guest"

$ExcludedDatastoreList = "pool", "mig", "local", "bkup", "old"
$Ping = New-Object System.Net.NetworkInformation.Ping

<# Begin Defining Functions:

  Write-Log - Write status / debugging output to screen and logfile

  VPostConfig - Set Post Provision VM Configuration
    Set CPU and RAM on Non-PTC Guests
    VMware Tools enable SyncTimeWithHost for Windows Guests
    VMware Tools enable UpgradeAtPowerCycle for all Guests
    Set BIOS BootDelay to 5000 ms

  Color-Write (Not-Implemented) - Enhanced log output not yet implemented

#>

Function Write-Log {
  $LogString = ""
  Foreach ($arg in $args) { $LogString += "$arg " }
  Write-Host -F Green "*" -NoNewLine
  Write-Host -F DarkGray "] " -NoNewLine
  Write-Host -F Gray $LogString
  $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  "$TimeStamp $LogString" | Out-File $LogFolder$LogFile -append
  }

Function Write-Null($Logged) {
  if ( $Logged -Like "Log" ) { $NewLine |  Out-File $LogFolder$LogFile -Append }
  Write-Host $Null
  }

Function VMPostConfig {

  $VMPostConfig                          = $Null
  $VMPostConfig                          = New-Object VMware.Vim.VirtualMachineConfigSpec
  $VMPostConfig.Tools                    = New-Object VMware.Vim.ToolsConfigInfo
  $VMPostConfig.BootOptions              = New-Object VMware.Vim.VirtualMachineBootOptions

  $VMPostConfig.NumCPUs                  = if ( $StaticTemplate -eq $False ) { $SizeCPU }
  $VMPostConfig.MemoryMB                 = if ( $StaticTemplate -eq $False ) { $SizeRAM*1024 }
  $VMPostConfig.CpuHotAddEnabled         = if ( $HotAddGuestList -Contains $VMView.Config.GuestId ) { $True } else { $False }
  $VMPostConfig.MemoryHotAddEnabled      = if ( $HotAddGuestList -Contains $VMView.Config.GuestId ) { $True } else { $False }
  $VMPostConfig.Tools.SyncTimeWithHost   = if ( $VMView.Config.GuestId -like "*win*") { $True } else { $False }
  $VMPostConfig.Tools.ToolsUpgradePolicy = if ( $VMView.Config.GuestId -like "*rhel*" -And $VMView.Config.Name -Like "LNX*" ) { "manual" } else { "manual" }
  $VMPostConfig.BootOptions.BootDelay    = 5000

  $VMPostConfigLog = $Null
  $VMPostConfigLog = New-Object PSObject |
  Add-Member -pass NoteProperty NumCPUs $VMPostConfig.NumCPUs |
  Add-Member -pass NoteProperty MemoryMB $VMPostConfig.MemoryMB |
  Add-Member -pass NoteProperty CpuHotAddEnabled $VMPostConfig.CpuHotAddEnabled |
  Add-Member -pass NoteProperty MemoryHotAddEnabled $VMPostConfig.MemoryHotAddEnabled |
  Add-Member -pass NoteProperty SyncTimeWithHost $VMPostConfig.Tools.SyncTimeWithHost |
  Add-Member -pass NoteProperty ToolsUpgradePolicy $VMPostConfig.Tools.ToolsUpgradePolicy |
  Add-Member -pass NoteProperty BootDelay $VMPostConfig.BootOptions.BootDelay
  
  Write-Log Performing VM Post Configuration:
  $VMPostConfigLog | Format-Table -Auto | Out-String
  $VMPostConfigLog | Format-Table -Auto | Out-String | Out-File $LogFolder$LogFile -Append
  
  $VMView.ReconfigVM($VMPostConfig)

  }

Function Not-Implemented
  {
    # DO NOT SPECIFY param(...)
    #    we parse colors ourselves.

    $allColors = ("-Black",   "-DarkBlue","-DarkGreen","-DarkCyan","-DarkRed","-DarkMagenta","-DarkYellow","-Gray",
                  "-Darkgray","-Blue",    "-Green",    "-Cyan",    "-Red",    "-Magenta",    "-Yellow",    "-White")
    $foreground = (Get-Host).UI.RawUI.ForegroundColor # current foreground
    $color = $foreground
    [bool]$nonewline = $false
    $sofar = ""
    $total = ""

    foreach($arg in $args) {
        if ($arg -eq "-nonewline") { $nonewline = $true }
        elseif ($arg -eq "-foreground")
        {
            if ($sofar) { Write-Host $sofar -foreground $color -nonewline }
            $color = $foregrnd
            $sofar = ""
        }
        elseif ($allColors -contains $arg)
        {
            if ($sofar) { Write-Host $sofar -foreground $color -nonewline }
            $color = $arg.substring(1)
            $sofar = ""
        }
        else
        {
            $sofar += "$arg "
            $total += "$arg "
        }
    }
    
    # last bit done special
    if (!$nonewline)
    {
        Write-Host $sofar -foreground $color
    }
    elseif($sofar)
    {
        Write-Host $sofar -foreground $color -nonewline
    }
  } # End Function Not-Implemented

Write-Host $Null
Write-Log Provision_SR.ps1 Version: $Version - Date: $BuildDate - $motd
Write-Log Begin Provisioning $InputFile.Name by $UserName from $UserDomainName \ $MachineName
Write-Null

Try { 

  <# Input Data Validation - Begin #>

  Write-Log Performing Input Validation:
  Write-Host $Null
  
  <# Verify Unique Values #>

  Write-Log Getting all VMs object
  $allvms = Get-VM

  $VMs | % {
     
    <# Verify VM does not already exist #>
    
    Write-Log Checking for VM $_.Name
    $VMNameCheck = $_.Name
    if ( $_.Name -Like $Null ) { Write-Error "No VM Name Specificed" }
    elseif ( $allvms | ?{$_.name -eq $VMNameCheck} ) { Write-Error "VM $VMNameCheck Already Exists" }

    <# Verify GuestID isnt Null #>
        
    if ( $_.Template -Like $Null -And $_.GuestID -Like $Null ) { Write-Error "No GuestID Specified" }
    
    <# Verify OSCustomization Spec does not already exist #>
    
    Write-Log Checking for Customization Spec $_.Name
    if ( Get-OSCustomizationSpec -Name $_.Name -ErrorAction SilentlyContinue ) { Write-Error "Customization Spec $VMNameCheck Already Exists" }


    <# Verify IP addresses #>
    
    #Write-Log Checking for IP Address $_.NIC1
    #$NIC1_IPError = $_.NIC1_IP
    #if ( $_.NIC1_IP -Like $Null ) { Write-Log No NIC1_IP Specified
    #} elseif (
    #  $Ping.Send($_.NIC1_IP).Status -eq "Success" ) {  Write-Error "IP Address $NIC1_IPError Exists" }
      # } else { Write-Log -noNewline IP $NIC1_IPError Verified Unpingable }
    Write-Host $Null 
    }


  <# Verify Unique Clusters Exist #>
  
  Write-Log Verifying Clusters
  $VMs | Select -Unique Cluster | % {
    if ( $_.Cluster-Like $Null ) { Write-Error "No Cluster Specified"
      } else {      
        $ClusterError = $_.Cluster
        if ( !( Get-Cluster $_.Cluster -ErrorAction SilentlyContinue ) ) { Write-Error "Cluster $ClusterError Not Found" }
      }
    }


  <# Verify Unique Base CustomizationSpecs Exist #>
  
  Write-Log Verifying BaseCustomizationSpecs
  $VMs | Select -Unique Cluster, BaseCustomizationSpec | % {
    if ( $_.BaseCustomizationSpec -NotLike $Null ) { 
      $BaseSpecError      = $_.BaseCustomizationSpec
      $ClusterObjectInput = Get-Cluster $_.Cluster
      $vCenterInput       = $ClusterObjectInput.Uid.Split("@:")[1]
      if ( !( Get-OSCustomizationSpec -Server $VCenterInput $_.BaseCustomizationSpec -ErrorAction SilentlyContinue ) ) { Write-Error "BaseCustomizationSpec $BaseSpecError Not Found" }
      }
    }


  <# Verify Unique Templates Exist #>
  
  Write-Log Verifying Templates
  $VMs | Select -Unique Cluster, Template | % {
    if ( $_.Template -NotLike $Null ) {
      $TemplateError = $_.Template
      if ( !( Get-Datacenter -Cluster $_.Cluster | Get-Template $_.Template -ErrorAction SilentlyContinue ) ) { Write-Error "Template $TemplateError Not Found" }
      }
    }
    

  <# Verify Folder Structure based on unique combinations #>
  
  Write-Log Verifying Folder Structure
  $VMs | Select -Unique Cluster, Folder* | % {
    if ( $_.Folder3 -notlike $Null ) { 
        $Folder1 = $_.Folder1 ; $Folder2 = $_.Folder2 ; $Folder3 = $_.Folder3
        if ( !( Get-Datacenter -Cluster $_.Cluster | Get-Folder $_.Folder1 -ErrorAction SilentlyContinue | Get-Folder $_.Folder2 -ErrorAction SilentlyContinue | Get-Folder $_.Folder3 -ErrorAction SilentlyContinue ) ) { Write-Error "Folder Structure Invalid:  $Folder1 / $Folder2 / $Folder3" }
    } elseif ( $_.Folder2 -notlike $Null ) { 
        $Folder1 = $_.Folder1 ; $Folder2 = $_.Folder2
        if ( !( Get-Datacenter -Cluster $_.Cluster | Get-Folder $_.Folder1 -ErrorAction SilentlyContinue | Get-Folder $_.Folder2 -ErrorAction SilentlyContinue ) ) { Write-Error "Folder Structure Invalid:  $Folder1 / $Folder2" }
    } elseif ( $_.Folder1 -notlike $Null ) { 
        $Folder1 = $_.Folder1
        if ( !( Get-Datacenter -Cluster $_.Cluster | Get-Folder $_.Folder1 -ErrorAction SilentlyContinue ) ) { Write-Error "Folder Structure Invalid:  $Folder1" }
    } else { Write-Error "No Folder1 Specified" }
  }  
    

  <# Verify DataStores Exist #>
  
  Write-Log Verifying DataStore Strings
  $VMs | Select -Unique Cluster, Datastore | % {
    if ( $_.DataStore -NotLike $Null ) {
      $DataStoreError = $_.Datastore
      $ExcludedDatastoreList | % { if ( $DataStoreError -Match $_ ) { Write-Error "DataStore Input `"$DataStoreError`" is on the exception list!" } }
      if ( !( Get-Datacenter -Cluster $_.Cluster | Get-DatastoreCluster *$DatastoreError* -ErrorAction SilentlyContinue ) -And !( Get-Datacenter -Cluster $_.Cluster | Get-Datastore *$DatastoreError* -ErrorAction SilentlyContinue ) ) { 
        Write-Error "No Datastores found matching $DatastoreError"
        }
      } else {
      $ClusterError = $_.Cluster
      if ( !( Get-Datacenter -Cluster $_.Cluster | Get-DatastoreCluster *$ClusterError* -ErrorAction SilentlyContinue ) -And !( Get-Datacenter -Cluster $_.Cluster | Get-Datastore *$ClusterError* -ErrorAction SilentlyContinue ) ) { 
        Write-Error "No Datastores found matching Cluster $ClusterError" }
      }
    }


  if  ( $VM.Datastore -NotLike $Null ) {
      if ( !( $DiskDestination = Get-DatastoreCluster *$Datastore*  –ErrorAction SilentlyContinue) ) { $DiskDestination = Get-Datastore *$Datastore* }
      } else {
      if ( !( $DiskDestination = Get-DatastoreCluster *$Cluster*  –ErrorAction SilentlyContinue) ) { $DiskDestination = Get-Datastore *$Cluster* }
      }


  <# Verify Unique PortGroups Exist #>
  
  Write-Log Verifying PortGroups
  $VMs | Select -Unique Cluster, NIC1_Portgroup | % {
    if ( $_.NIC1_Portgroup -Like $Null ) { Write-Error "No NIC1_Portgroup Specified"
      } else {      
        $PortgroupError = $_.NIC1_Portgroup
        $ClusterError = $_.Cluster
        if ( !( Get-Cluster $_.Cluster | Get-VMHost | ? { $_.ConnectionState -Like "Connected" } | Get-Random | Get-VirtualPortGroup -Name $_.NIC1_Portgroup -ErrorAction SilentlyContinue ) ) { Write-Error "PortGroup $PortGroupError Not Found on Cluster: $ClusterError" }
      }
    }
  $VMs | Select -Unique Cluster, NIC2_Portgroup | % {
    if ( $_.NIC2_Portgroup ) {
      $PortgroupError = $_.NIC2_Portgroup
      $ClusterError = $_.Cluster
      if ( !( Get-Cluster $_.Cluster | Get-VMHost | ? { $_.ConnectionState -Like "Connected" } | Get-Random | Get-VirtualPortGroup -Name $_.NIC2_Portgroup -ErrorAction SilentlyContinue ) ) { Write-Error "PortGroup $PortGroupError Not Found on Cluster: $ClusterError" }
      }
    }
  $VMs | Select -Unique Cluster, NIC3_Portgroup | % {
    if ( $_.NIC3_Portgroup ) {
      $PortgroupError = $_.NIC3_Portgroup
      $ClusterError = $_.Cluster
      if ( !( Get-Cluster $_.Cluster | Get-VMHost | ? { $_.ConnectionState -Like "Connected" } | Get-Random | Get-VirtualPortGroup -Name $_.NIC3_Portgroup -ErrorAction SilentlyContinue ) ) { Write-Error "PortGroup $PortGroupError Not Found on Cluster: $ClusterError" }
      }
    }
  $VMs | Select -Unique Cluster, NIC4_Portgroup | % {
    if ( $_.NIC4_Portgroup ) {
      $PortgroupError = $_.NIC4_Portgroup
      $ClusterError = $_.Cluster
      if ( !( Get-Cluster $_.Cluster | Get-VMHost | ? { $_.ConnectionState -Like "Connected" } | Get-Random | Get-VirtualPortGroup -Name $_.NIC4_Portgroup -ErrorAction SilentlyContinue ) ) { Write-Error "PortGroup $PortGroupError Not Found on Cluster: $ClusterError" }
      }
    }

 
  <# Validate IP and Mask Formatting #>
  
  Write-Log Validating IP Address / Subnet Mask Format
  $VMs | % { ( $_ | Select-Object -Property "*_IP", "*_Subnet", "Gateway" ).PSObject.Properties | ? { $_.Value } | % { [System.Net.IPAddress]::Parse($_.Value) } | Out-Null }

<# Input Data Validation - End #>


#######################################
# Begin Provisioning Loop
#######################################

ForEach ( $VM in $VMs ) {

###########################################
# In Loop Global Commands
###########################################

  
  $GuestOS = $VM.Folder1.ToString()


###########################################
# If the Template field is blank provision an empty VM
###########################################

If ( $VM.Template -like $null ) { 
  
  $StaticTemplate = $False

  Write-Null Log

  Write-Log Provisioning Blank VM: $VM.Name

  ###########################################
  # Disks:  Support up to 4 Disks in GB.
  ###########################################
  
  if ( $VM.Disk4 -gt 0 ) { $Disks = ([int]($VM.Disk1)*1024), ([int]($VM.Disk2)*1024), ([int]($VM.Disk3)*1024), ([int]($VM.Disk4)*1024) }
    elseif
     ( $VM.Disk3 -gt 0 ) { $Disks = ([int]($VM.Disk1)*1024), ([int]($VM.Disk2)*1024), ([int]($VM.Disk3)*1024) }
    elseif
     ( $VM.Disk2 -gt 0 ) { $Disks = ([int]($VM.Disk1)*1024), ([int]($VM.Disk2)*1024) }
    elseif
     ( $VM.Disk1 -gt 0 ) { $Disks = ([int]($VM.Disk1)*1024) }
  
  $DiskSizeMB = ($Disks | Measure-Object -sum).Sum
  $SizeMB = ($Disks | Measure-Object -sum).Sum + ( 1024*$VM.MemoryGB )
  $DiskSizeGB = $DiskSizeMB/1024
  $SizeGB = $SizeMB/1024
  Write-Log VM Size: $VM.NumCPU vCPUs - $VM.MemoryGB GB RAM - $DiskSizeGB GB Disk - $SizeGB GB Size on Disk

  ###########################################
  # Network:  Support for up to 4 Network Labels.
  ###########################################

  if ( $VM.NIC4_Portgroup -notlike $null ) { $Networks = ( $VM.NIC1_Portgroup, $VM.NIC2_Portgroup, $VM.NIC3_Portgroup, $VM.NIC4_Portgroup ) }
    elseif 
     ( $VM.NIC3_Portgroup -notlike $null ) { $Networks = ( $VM.NIC1_Portgroup, $VM.NIC2_Portgroup, $VM.NIC3_Portgroup ) }
    elseif 
     ( $VM.NIC2_Portgroup -notlike $null ) { $Networks = ( $VM.NIC1_Portgroup, $VM.NIC2_Portgroup ) }
    elseif 
     ( $VM.NIC1_Portgroup -notlike $null ) { $Networks = ( $VM.NIC1_Portgroup ) }
   
   Write-Log Networks: $Networks

  ###########################################
  # Folder Selection:  Use up to three folders ( root folder / sub folder ).
  # NOTE:  Root folder and subfolder names should be unique.
  ###########################################

  if ( $VM.Folder3 -notlike $null ) { 
    $Location = Get-Datacenter -Cluster $VM.Cluster | Get-Folder -Name $VM.Folder1 | Get-Folder -Name $VM.Folder2 | Get-Folder -Name $VM.Folder3
    Write-Log Folder Hierarchy $VM.Folder1 / $VM.Folder2 / $VM.Folder3
    } elseif
     ( $VM.Folder2 -notlike $null ) { 
    $Location = Get-Datacenter -Cluster $VM.Cluster | Get-Folder -Name $VM.Folder1 | Get-Folder -Name $VM.Folder2
    Write-Log Folder Hierarchy $VM.Folder1 / $VM.Folder2
    } elseif
     ( $VM.Folder1 -notlike $null ) {
    $Location = Get-Datacenter -Cluster $VM.Cluster | Get-Folder -Name $VM.Folder1
    Write-Log Folder Hierarchy $VM.Folder1
    }
   
  Write-Log Destination Folder $Location
   
  $Cluster   = $VM.Cluster.ToString()
  $Datastore = $VM.Datastore.ToString()

 if  ( $VM.Datastore -NotLike $Null ) {
      if ( !( $DiskDestination = Get-DatastoreCluster *$Datastore*  –ErrorAction SilentlyContinue ) ) { $DiskDestination = Get-Datastore *$Datastore* }
      } else {
      if ( !( $DiskDestination = Get-DatastoreCluster  –ErrorAction SilentlyContinue) ) { $DiskDestination = Get-Datastore  }
      }
 
  $DiskDestination = $DiskDestination | ? {     $_.FreeSpaceGB -gt      ($SizeGB + $FreeSpaceGB) `
                                            -And $_.State      -NotLike "Maintenance" `
                                            -And $_.Name       -NotLike "*pool*" `
                                            -And $_.Name       -NotLike "*mig*" `
                                            -And $_.Name       -NotLike "*local*" `
                                            -And $_.Name       -NotLike "*bkup*" `
                                            -And $_.Name       -NotLike "*old*" `
                                            } | Sort FreeSpaceGB, Name | Select -last 1

  if ( $DiskDestination -eq $Null ) { Write-Error "No DiskDestination Found" }
  
  Write-Log Destination Datastore or DatastoreCluster $DiskDestination
  
  Write-Log Provisioning $VM.name in $Cluster on $DiskDestination in folder $Location
  
  New-VM -ResourcePool $Cluster -Name $VM.Name -Location $Location -Datastore $DiskDestination -DiskMB $Disks -MemoryMB ( 1024*$VM.MemoryGB ) -NumCpu $VM.NumCpu -CD -GuestID $VM.GuestID -NetworkName $Networks | Out-Null
  
  $VMObject = Get-VM $VM.Name
  $VMView   = Get-View $VMObject
  $SizeCPU  = [int]($VM.NumCPU)
  $SizeRAM  = [int]($VM.MemoryGB)

  VMPostConfig
  
  if ( $VM.GuestID -match "windows7Server64Guest" ) { Write-Log guestid $VM.GuestID - Setting VMXNET3 
    Get-VM $VM.Name | Get-NetworkAdapter | % { Set-NetworkAdapter -NetworkAdapter $_ -Type Vmxnet3 -Confirm:$false | Out-Null }
    }
    
  $VMDataStore1 = $VMObject | Get-Datastore | Select -First 1
  $VMNic1MAC = $VMObject.NetworkAdapters | ? { $_.name -like "Network Adapter 1" } | select MacAddress
  
  Write-Log Provisioned $VMView.Config.name - $VMView.Config.UUID  on $VMDatastore1.Name

  Write-Null

  $ProvisionedList = .{
    $ProvisionedList 
    New-Object PSObject | 
    Add-Member -pass NoteProperty VM $VMView.Config.name |
    Add-Member -pass NoteProperty UUID $VMView.Config.UUID |
    Add-Member -pass NoteProperty DataStore $VMDataStore1.Name |
    Add-Member -pass NoteProperty NIC_1-MAC $VMNic1MAC.MacAddress |
    Add-Member -pass NoteProperty NIC_1-IP $VM.NIC1_IP 
    }

  } ## End Blank VM Provisioning Loop

########################################################################################################################################################################
# If the Template field is not null then deploy a template                                                                                                 #############
########################################################################################################################################################################

elseif ( $VM.Template -notlike $null ) {
  
  Write-Null Log
  Write-Log Provisioning VM: $VM.Name from $VM.Template
  
  $ClusterObject   = Get-Cluster $VM.Cluster
  $vCenter         = $ClusterObject.Uid.Split("@:")[1]
  
  Write-Log Using Cluster: $ClusterObject.Name on vCenter: $vCenter
 
  <#  Determine the size of the VM, base template size is minimum #>
  
  if ( $VM.Template -Match "PTC" ) { $StaticTemplate = $True } else { $StaticTemplate = $False }
  $TemplateObject = Get-Template $VM.Template
  $TemplateView   = $TemplateObject | Get-View
  $TemplateDisks  = $TemplateObject | Get-HardDisk
  #$TemplateOSGB   = ( $TemplateDisks | Select -Index 0 ).CapacityGB
  #$TemplateAppGB  = ( $TemplateDisks | Select -Index 1 ).CapacityGB
  #if ( $TemplateAppGB -eq $Null ) { $TemplateAppGB = 0 }
  #Write-Log Template OS Disk: $TemplateOSGB GB
  #Write-Log Template App Disk: $TemplateAppGB GB
  
      
  $TemplateDiskGB = ( $TemplateDisks | Measure-Object -sum CapacityGB ).Sum
  $TemplateMemGB  = $TemplateView.Config.Hardware.MemoryMB/1024
  $TemplateNumCPU = $TemplateView.Config.Hardware.NumCPU
  $TemplateSizeGB = $TemplateDiskGB + $TemplateMemGB
  
  
  <# Calculate Disk size based on Static Template or OS Type #>
  
  if ( $StaticTemplate ) {
    $SizeDisk = $TemplateDiskGB
    Write-Log Static Template.. Using template hardware configuration
    } 
  else {
    $SRDiskGB = [int]($VM.Disk1) + [int]($VM.Disk2) + [int]($VM.Disk3) + [int]($VM.Disk4)
    $SizeDisk = $TemplateDiskGB + $SRDiskGB
    Write-Log App Disks: $VM.Disk1 $VM.Disk2 $VM.Disk3 $VM.Disk4 GB
    }
    
    $SRMemGB  = [int]($VM.MemoryGB)
    $SRNumCPU = [int]($VM.NumCPU)
      
  if ( $SRNumCPU -gt $TemplateNumCPU ) {
    $SizeCPU = $SRNumCPU
    } else {
    $SizeCPU = $TemplateNumCPU
    }
    
  if ( $SRMemGB -gt $TemplateMemGB ) {
    $SizeRAM = $SRMemGB
    } else {
    $SizeRAM = $TemplateMemGB
    }
  
  $SizeGB = $SizeRAM + $SizeDisk
    
  Write-Log VM Size: $SizeCPU vCPUs - $SizeRAM GB RAM - $SizeDisk GB Disk 
  Write-Log VM Size on disk: $SizeGB GB
  <# Support 3 folders deep for location #>
  
  if ( $VM.Folder3 -notlike $null ) {
    $Location = Get-Datacenter -Cluster $VM.Cluster | Get-Folder $VM.Folder1 | Get-Folder $VM.Folder2 | Get-Folder $VM.Folder3
    Write-Log Folder Hierarchy $VM.Folder1 / $VM.Folder2 / $VM.Folder3 #debug
  } elseif ($VM.Folder2 -notlike $null ) {
    $Location = Get-Datacenter -Cluster $VM.Cluster | Get-Folder $VM.Folder1 | Get-Folder $VM.Folder2
    Write-Log Folder Hierarchy $VM.Folder1 / $VM.Folder2 #debug
  } else { 
    $Location = Get-Datacenter -Cluster $VM.Cluster | Get-Folder $VM.Folder1
    Write-Log Folder Hierarchy $VM.Folder1 #debug
  }
 
  Write-Log Destination Folder $Location
  
  <# Select Destination Datastore #>
  
  $Cluster   = $VM.Cluster.ToString()
  $Datastore = $VM.Datastore.ToString()

  if  ( $VM.Datastore -NotLike $Null ) {
      if ( !( $DiskDestination = Get-DatastoreCluster *$Datastore* –ErrorAction SilentlyContinue ) ) { $DiskDestination = Get-Datastore *$Datastore* }
      } else {
      if ( !( $DiskDestination = Get-DatastoreCluster –ErrorAction SilentlyContinue ) ) { $DiskDestination = Get-Datastore  }
      }
 
  $DiskDestination = $DiskDestination | ? {     $_.FreeSpaceGB -gt      ($SizeGB + $FreeSpaceGB) `
                                            -And $_.State      -NotLike "Maintenance" `
                                            -And $_.Name       -NotLike "*pool*" `
                                            -And $_.Name       -NotLike "*mig*" `
                                            -And $_.Name       -NotLike "*local*" `
                                            -And $_.Name       -NotLike "*bkup*" `
                                            -And $_.Name       -NotLike "*old*" `
                                            } | Sort FreeSpaceGB, Name | Select -last 1
                                                                       
  if ( $DiskDestination -eq $Null ) { Write-Error "No DiskDestination Found" }
    
  Write-Log Destination Datastore or DatastoreCluster $DiskDestination
  
  Write-Null
  
# $ExcludedDatastoreList | % { if ( $DiskDestination.Name -Match $_ ) { Write-Error "DiskDestination is on the exception list!" } }

  <# Create and apply dynamic customization specification #>

  $CustomizationSpec = New-OSCustomizationSpec -Server $VCenter -Name $VM.Name -Spec ( Get-OSCustomizationSpec -Server $VCenter $VM.BaseCustomizationSpec )
   
  $StaleCustomizationSpec = $CustomizationSpec
   
  Write-Log Created new Guest Customization Specification $CustomizationSpec from $VM.BaseCustomizationSpec #debug
   
  Write-Log Provisioning $VM.name from $VM.Template in $Cluster on $DiskDestination in folder $Location
  
  New-VM -Name $VM.Name -Template (Get-Template $VM.Template) -ResourcePool $Cluster -Datastore $DiskDestination -Location $Location | Out-Null
 
  Write-Null
  
  if ( $GuestOS -Like "Windows" -or $GuestOS -Like "Desktop" ) {
    
    
    <#
        Build The Windows Customization Specification and add any NICs
        Windows Specs Need -Dns for each NIC specified in the in the NIC Mapping 
    #>

    
    Write-Log Building Windows NIC Mapping
    
    $CustomizationSpec | Set-OSCustomizationSpec -NamingScheme Fixed -NamingPrefix $VM.Name | Out-Null
    $NicMap = $CustomizationSpec | Get-OSCustomizationNicMapping

    if ($VM.NIC1_IP -notlike $null) {
      Write-Log Setting Customization for first NIC - IP: $VM.NIC1_IP  Mask: $VM.NIC1_Subnet  GW: $VM.Gateway
      $CustomizationSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -Position 1 -IpAddress $VM.NIC1_IP -SubnetMask $VM.NIC1_Subnet -DefaultGateway $VM.Gateway -Dns $NicMap.Dns[0], $NicMap.Dns[1], $NicMap.Dns[2]  | Out-Null
      Write-Log Changing PortGroup for first nic to: $VM.NIC1_Portgroup
      Get-VM $VM.Name | Get-NetworkAdapter | ? { $_.Name -like "Network adapter 1" } | Set-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC1_Portgroup ) -Confirm:$False | Set-NetworkAdapter -StartConnected:$True -confirm:$False  | Out-Null
    }

    if ($VM.NIC2_IP -notlike $null) {
      Write-Log Setting Customization for second NIC - IP: $VM.NIC2_IP  Mask: $VM.NIC1_Subnet
      $CustomizationSpec | New-OSCustomizationNicMapping -IpMode UseStaticIp -Position 2 -IpAddress $VM.NIC2_IP -SubnetMask $VM.NIC2_Subnet -DefaultGateway 0.0.0.0 -Dns $NicMap.Dns[0], $NicMap.Dns[1], $NicMap.Dns[2] | Out-Null
      Write-Log Adding Second NIC on PortGroup: $VM.NIC2_Portgroup
      Get-VM $VM.Name | New-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC2_Portgroup ) -StartConnected -confirm:$false | Out-Null
    }

    if ($VM.NIC3_IP -notlike $null) {
      Write-Log Setting Customization for third NIC - IP: $VM.NIC3_IP  Mask: $VM.NIC1_Subnet
      $CustomizationSpec | New-OSCustomizationNicMapping -IpMode UseStaticIp -Position 3 -IpAddress $VM.NIC3_IP -SubnetMask $VM.NIC3_Subnet -DefaultGateway 0.0.0.0 -Dns $NicMap.Dns[0], $NicMap.Dns[1], $NicMap.Dns[2] | Out-Null
      Write-Log adding third NIC on PortGroup: $VM.NIC3_Portgroup
      Get-VM $VM.Name | New-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC3_Portgroup ) -StartConnected -confirm:$false | Out-Null
    }

    if ($VM.NIC4_IP -notlike $null) {
      Write-Log Setting Customization for fourth NIC - IP: $VM.NIC4_IP  Mask: $VM.NIC1_Subnet
      $CustomizationSpec | New-OSCustomizationNicMapping -IpMode UseStaticIp -Position 4 -IpAddress $VM.NIC4_IP -SubnetMask $VM.NIC4_Subnet -DefaultGateway 0.0.0.0 -Dns $NicMap.Dns[0], $NicMap.Dns[1], $NicMap.Dns[2] | Out-Null
      Write-Log adding fourth NIC on PortGroup: $VM.NIC4_Portgroup
      Get-VM $VM.Name | New-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC4_Portgroup ) -StartConnected -confirm:$false | Out-Null
    }

  } elseif ( $GuestOS -like "Linux" ) {
   
    #######################################################
    # Build the Linux Customization Spec
    # Linux Specs Get DNS from the Base Customization Spec
    #######################################################
    
    Write-Log Building Linux NIC Mapping

    $CustomizationSpec | Set-OSCustomizationSpec -NamingScheme Fixed -NamingPrefix $VM.Name.ToLower() | Out-Null
       
    if ($VM.NIC1_IP -notlike $null) {
      Write-Log Setting Customization for first NIC - IP: $VM.NIC1_IP  Mask: $VM.NIC1_Subnet  GW: $VM.Gateway
      $CustomizationSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -Position 1 -IpAddress $VM.NIC1_IP -SubnetMask $VM.NIC1_Subnet -DefaultGateway $VM.Gateway | Out-Null
      Write-Log Changing PortGroup for first nic to: $VM.NIC1_Portgroup
      Get-VM $VM.Name | Get-NetworkAdapter | ? { $_.Name -like "Network adapter 1" } | Set-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC1_Portgroup ) -Confirm:$False | Set-NetworkAdapter -StartConnected:$True -confirm:$False | Out-Null
    }
    
    if ($VM.NIC2_IP -notlike $null) {
      Write-Log Setting Customization for second NIC - IP: $VM.NIC2_IP  Mask: $VM.NIC2_Subnet
      $CustomizationSpec | New-OSCustomizationNicMapping -IpMode UseStaticIp -Position 2 -IpAddress $VM.NIC2_IP -SubnetMask $VM.NIC2_Subnet -DefaultGateway 0.0.0.0 | Out-Null
      Write-Log Adding Second NIC on PortGroup: $VM.NIC2_Portgroup
      if ( $StaticTemplate ) { Get-VM $VM.Name | Get-NetworkAdapter | ? { $_.Name -like "Network adapter 2" } | Set-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC2_Portgroup ) -Confirm:$False | Set-NetworkAdapter -StartConnected:$True -confirm:$False | Out-Null }
      else { Get-VM $VM.Name | New-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC2_Portgroup ) -StartConnected -confirm:$false | Out-Null }
    }
    
    if ($VM.NIC3_IP -notlike $null) {
      Write-Log Setting Customization for third NIC - IP: $VM.NIC3_IP  Mask: $VM.NIC3_Subnet
      $CustomizationSpec | New-OSCustomizationNicMapping -IpMode UseStaticIp -Position 3 -IpAddress $VM.NIC3_IP -SubnetMask $VM.NIC3_Subnet -DefaultGateway 0.0.0.0 | Out-Null
      Write-Log Adding third NIC on PortGroup: $VM.NIC3_Portgroup
      if ( $StaticTemplate ) { Get-VM $VM.Name | Get-NetworkAdapter | ? { $_.Name -like "Network adapter 3" } | Set-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC3_Portgroup ) -Confirm:$False | Set-NetworkAdapter -StartConnected:$True -confirm:$False | Out-Null }
      else { Get-VM $VM.Name | New-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC3_Portgroup ) -StartConnected -confirm:$false | Out-Null }
    }
    
    if ($VM.NIC4_IP -notlike $null) {
      Write-Log Setting Customization for fourth NIC - IP: $VM.NIC4_IP  Mask: $VM.NIC4_Subnet
      $CustomizationSpec | New-OSCustomizationNicMapping -IpMode UseStaticIp -Position 4 -IpAddress $VM.NIC4_IP -SubnetMask $VM.NIC4_Subnet -DefaultGateway 0.0.0.0 | Out-Null
      Write-Log adding fourth NIC on PortGroup: $VM.NIC4_Portgroup
      if ( $StaticTemplate ) { Get-VM $VM.Name | Get-NetworkAdapter | ? { $_.Name -like "Network adapter 4" } | Set-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC4_Portgroup ) -Confirm:$False | Set-NetworkAdapter -StartConnected:$True -confirm:$False | Out-Null }
      else { Get-VM $VM.Name | New-NetworkAdapter -PortGroup ( Get-VirtualPortGroup -Name $VM.NIC4_Portgroup ) -StartConnected -confirm:$false | Out-Null }
    }
    
  }
  
  Write-Null
  
# Apply customization spec and add any additional resources specified in the SR 
 
  Write-Log Applying Customization Specification $CustomizationSpec and adding additional resources
  
  $ErrorActionPreference = "Continue"  # Errors ok to Allow Provisioning of Blank Templates
    
  Set-VM -OSCustomizationSpec $VM.Name -VM $VM.Name -Confirm:$False | Out-Null
    
  $ErrorActionPreference = "Stop" # Resume Stop on Error
  
  $VMObject = Get-VM $VM.Name
  $VMView = Get-View $VMObject
  #$VMDisks = Get-HardDisk $VMObject
  
  # Need additional disks added?
  if ( $StaticTemplate -eq $False ) {
  
    if ( $VM.Disk1 -notlike $Null ) {
      New-HardDisk -CapacityGB $VM.Disk1 -VM $VM.Name | Out-Null
      Write-Log App Disk 1 Added:  $VM.Disk1 GB
      }
      
    if ($VM.Disk2 -notlike $null ) {
      New-HardDisk -CapacityGB $VM.Disk2 -VM $VM.Name | Out-Null
      Write-Log App Disk 2 Added:  $VM.Disk2 GB
      }
    
    if ($VM.Disk3 -notlike $null ) {
      New-HardDisk -CapacityGB $VM.Disk3 -VM $VM.Name | Out-Null
      Write-Log App Disk 3 Added:  $VM.Disk3 GB
      }
    
    if ($VM.Disk4 -notlike $null ) {
      New-HardDisk -CapacityGB $VM.Disk4 -VM $VM.Name | Out-Null
      Write-Log App Disk 4 Added:  $VM.Disk4 GB
      }
    }
 <# Perform VM Post Configuration Tasks #>

  Write-Null

  VMPostConfig  # Call Post Config API Function

  if ( $VMView.config.GuestID -match "windows7Server64Guest" ) { 
    Write-Log GuestId is $VMView.Config.GuestId - Setting VMXNET3 
    $VMObject | Get-NetworkAdapter | % { Set-NetworkAdapter -NetworkAdapter $_ -Type Vmxnet3 -Confirm:$false } | Out-Null
    }

  Write-Log Powering on VM: $VMObject.Name 
  Start-VM -VM $VMObject -RunAsync | Out-Null
  
  $CustomizationSpec | Export-Clixml $LogFolder$LogFileCustSpec
  $CustomizationSpec | Get-OSCustomizationNicMapping | Export-Clixml $LogFolder$LogFileCustSpecNic
  
  Write-Log Removing Customization Spec $VM.Name
  Remove-OSCustomizationSpec -Server $VCenter $CustomizationSpec -Confirm:$False
  $StaleCustomizationSpec = $Null
  
  $VMDataStore1 = $VMObject | Get-Datastore | Select -First 1
  $VMNic1MAC = $VMObject.NetworkAdapters | ? { $_.name -like "Network Adapter 1" } | select MacAddress
  
  Write-Log Provisioned $VMView.Config.name - $VMView.Config.UUID  on $VMDatastore1.Name

  Write-Null

  $ProvisionedList = .{
    $ProvisionedList 
    New-Object PSObject | 
    Add-Member -pass NoteProperty VM $VMView.Config.name |
    Add-Member -pass NoteProperty Role $VM.Role |
    Add-Member -pass NoteProperty UUID $VMView.Config.UUID |
    Add-Member -pass NoteProperty DataStore $VMDataStore1.Name |
    Add-Member -pass NoteProperty NIC_1-MAC $VMNic1MAC.MacAddress |
    Add-Member -pass NoteProperty NIC_1-IP $VM.NIC1_IP 
    }
 
  } # End Template Provisioning 


} # End of CSV | ForEach Loop
 
} # End of Try

Catch [exception] {
  $ErrorExit = $True
  Write-Host $Null
  Write-Log ERROR - Halting Provisioning
  Write-Log $("ERROR - " + $_.InvocationInfo.PositionMessage)
  Write-Log $("ERROR - " + $_.Exception.GetType().FullName)
  Write-Log $("ERROR - " + $_.Exception.Message)
  }


Finally { 
  if ( $ErrorExit -eq $True ) {
    Write-Log Provisioning of $InputFile.Name Aborted
    } else {
    Write-Log Provisioning of $InputFile.Name Complete
    }

  if ( $StaleCustomizationSpec -notlike $Null ) {
    Write-Log Removing Stale Customization Spec $StaleCustomizationSpec
    Remove-OSCustomizationSpec $StaleCustomizationSpec -Confirm:$False    
    }
    
  Write-Log The following VMs have been provisioned:
  $ProvisionedList | Format-Table -Auto | Out-String
  $ProvisionedList | Format-Table -Auto | Out-String | Out-File $LogFolder$LogFile -Append
  
  }