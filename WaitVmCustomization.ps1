<#

.SYNOPSIS 
Waits customization process for list virtual machines to completes.

.DESCRIPTION 
Waits customization process for list virtual machines to completes. 
The script returns if customization process ends for all virtual machines or if the specified timeout elapses. 
The script returns PSObject for each specified VM. 
The output object has VM and CustomizationStatus properties.

.EXAMPLE 
$vm = 1..10 | foreach { New-VM -Template WindowsXPTemplate -OSCustomizationSpec WindowsXPCustomizaionSpec -Name "winxp-$_" } 
.\WaitVmCustomization.ps1 -vmList $vm -timeoutSeconds 600

.NOTES 
The script is based on sveral vCenter events. 
* VmStarting event – this event is posted on power on operation 
* CustomizationStartedEvent event – this event is posted for VM when customiztion has started 
* CustomizationSucceeded event – this event is posted for VM when customization has successfully completed 
* CustomizationFailed – this event is posted for VM when customization has failed

Possible CustomizationStatus values are: 
* "VmNotStarted" – if it was not found VmStarting event for specific VM. 
* "CustomizationNotStarted" – if it was not found CustomizationStarterdEvent for specific VM. 
* "CustomizationStarted" – CustomizationStartedEvent was found, but Succeeded or Failed event were not found 
* "CustomizationSucceeded" – CustomizationSucceeded event was found for this VM 
* "CustomizationFailed" – CustomizationFailed event wass found for this VM

#> 
[CmdletBinding()] 
param( 
   # VMs to monitor for OS customization completion 
   [Parameter(Mandatory=$true)] 
   [ValidateNotNullOrEmpty()] 
   [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]] $vmList, 
   
   # timeout in seconds to wait 
   [int] $timeoutSeconds = 600 
)

# constants for status 
      $STATUS_VM_NOT_STARTED = "VmNotStarted" 
      $STATUS_CUSTOMIZATION_NOT_STARTED = "CustomizationNotStarted" 
      $STATUS_STARTED = "CustomizationStarted" 
      $STATUS_SUCCEEDED = "CustomizationSucceeded" 
      $STATUS_FAILED = "CustomizationFailed" 
      
      $STATUS_NOT_COMPLETED_LIST = @( $STATUS_CUSTOMIZATION_NOT_STARTED, $STATUS_STARTED ) 
      
# constants for event types      
      $EVENT_TYPE_CUSTOMIZATION_STARTED = "VMware.Vim.CustomizationStartedEvent" 
      $EVENT_TYPE_CUSTOMIZATION_SUCCEEDED = "VMware.Vim.CustomizationSucceeded" 
      $EVENT_TYPE_CUSTOMIZATION_FAILED = "VMware.Vim.CustomizationFailed" 
      $EVENT_TYPE_VM_START = "VMware.Vim.VmStartingEvent"

# seconds to sleep before next loop iteration 
      $WAIT_INTERVAL_SECONDS = 15 
      
function main($vmList, $timeoutSeconds) { 
   # the moment in which the script has started 
   # the maximum time to wait is measured from this moment 
   $startTime = Get-Date 
   
   # we will check for "start vm" events 5 minutes before current moment 
   $startTimeEventFilter = $startTime.AddMinutes(-5) 
   
   # initializing list of helper objects 
   # each object holds VM, customization status and the last VmStarting event 
   $vmDescriptors = New-Object System.Collections.ArrayList 
   foreach($vm in $vmList) { 
      Write-Host "Start monitoring customization process for vm '$vm'" 
      $obj = "" | select VM,CustomizationStatus,StartVMEvent 
      $obj.VM = $vm 
      # getting all events for the $vm, 
      #  filter them by type, 
      #  sort them by CreatedTime, 
      #  get the last one 
      $obj.StartVMEvent = Get-VIEvent -Entity $vm -Start $startTimeEventFilter | 
         where { $_ -is $EVENT_TYPE_VM_START } | 
         Sort CreatedTime | 
         Select -Last 1 
         
      if (-not $obj.StartVMEvent) { 
         $obj.CustomizationStatus = $STATUS_VM_NOT_STARTED 
      } else { 
         $obj.CustomizationStatus = $STATUS_CUSTOMIZATION_NOT_STARTED 
      } 
      
      [void]($vmDescriptors.Add($obj)) 
   }         
   
   # declaring script block which will evaulate whether 
   # to continue waiting for customization status update 
   $shouldContinue = { 
      # is there more virtual machines to wait for customization status update 
      # we should wait for VMs with status $STATUS_STARTED or $STATUS_CUSTOMIZATION_NOT_STARTED 
      $notCompletedVms = $vmDescriptors | 
         where { $STATUS_NOT_COMPLETED_LIST -contains $_.CustomizationStatus }

      # evaulating the time that has elapsed since the script is running 
      $currentTime = Get-Date 
      $timeElapsed = $currentTime – $startTime 
      
      $timoutNotElapsed = ($timeElapsed.TotalSeconds -lt $timeoutSeconds) 
      
      # returns $true if there are more virtual machines to monitor 
      # and the timeout is not elapsed 
      return ( ($notCompletedVms -ne $null) -and ($timoutNotElapsed) ) 
   } 
      
   while (& $shouldContinue) { 
      foreach ($vmItem in $vmDescriptors) { 
         $vmName = $vmItem.VM.Name 
         switch ($vmItem.CustomizationStatus) { 
            $STATUS_CUSTOMIZATION_NOT_STARTED { 
               # we should check for customization started event 
               $vmEvents = Get-VIEvent -Entity $vmItem.VM -Start $vmItem.StartVMEvent.CreatedTime 
               $startEvent = $vmEvents | where { $_ -is $EVENT_TYPE_CUSTOMIZATION_STARTED } 
               if ($startEvent) { 
                  $vmItem.CustomizationStatus = $STATUS_STARTED 
                  Write-Host "Customization for VM '$vmName' has started" 
               } 
               break; 
            } 
            $STATUS_STARTED { 
               # we should check for customization succeeded or failed event 
               $vmEvents = Get-VIEvent -Entity $vmItem.VM -Start $vmItem.StartVMEvent.CreatedTime 
               $succeedEvent = $vmEvents | where { $_ -is $EVENT_TYPE_CUSTOMIZATION_SUCCEEDED } 
               $failedEvent = $vmEvents | where { $_ -is $EVENT_TYPE_CUSTOMIZATION_FAILED } 
               if ($succeedEvent) { 
                  $vmItem.CustomizationStatus = $STATUS_SUCCEEDED 
                  Write-Host "Customization for VM '$vmName' has successfully completed" 
               } 
               if ($failedEvent) { 
                  $vmItem.CustomizationStatus = $STATUS_FAILED 
                  Write-Host "Customization for VM '$vmName' has failed" 
               } 
               break; 
            } 
            default { 
               # in all other cases there is nothing to do 
               #    $STATUS_VM_NOT_STARTED -> if VM is not started, there's no point to look for customization events 
               #    $STATUS_SUCCEEDED -> customization is already succeeded 
               #    $STATUS_FAILED -> customization 
               break; 
            } 
         } # enf of switch 
      } # end of the freach loop 
      
      Write-Host "Sleeping for $WAIT_INTERVAL_SECONDS seconds" 
      Sleep $WAIT_INTERVAL_SECONDS 
   } # end of while loop 
   
   # preparing result, without the helper column StartVMEvent 
   $result = $vmDescriptors | select VM,CustomizationStatus 
   return $result 
}

#calling the main function 
main $vmList $timeoutSeconds