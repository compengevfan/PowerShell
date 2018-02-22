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