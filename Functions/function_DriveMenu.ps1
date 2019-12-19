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