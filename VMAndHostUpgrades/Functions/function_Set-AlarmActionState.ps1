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