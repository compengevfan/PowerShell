Function DisplayMenuReturnSelection
{
    Param(
        [Parameter(Mandatory=$True)] $Items,
        [Parameter(Mandatory=$True)] $NameField
    )

    $i = 0

    $Items_In_Array = @()
    foreach ($Item in $Items)
    {
        $i++
        $Items_In_Array += New-Object -Type PSObject -Property (@{
		Identifyer = $i
        ItemName = $Item.$NameField
        })
    }
}