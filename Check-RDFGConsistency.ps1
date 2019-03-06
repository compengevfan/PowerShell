[xml]$XML = symdg list -output xml_e

foreach ($DG in $XML.SymCLI_ML.DG)
{
    [xml]$RDFXML = symrdf -g $DG.DG_Info.name query -output xml_e

    if ($null -eq $RDFXML.SymCLI_ML.DG.RDF_Pair.Count) { Write-Host $DG.DG_Info.name $($RDFXML.SymCLI_ML.DG.RDF_Pair.pair_state) }
    else { Write-Host $DG.DG_Info.name $($RDFXML.SymCLI_ML.DG.RDF_Pair[0].pair_state) }
}
