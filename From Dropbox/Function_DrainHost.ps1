[cmdletbinding()] 
Param ( 
    $servers = "devqc-vs01.ff.p10"

) 

Function DrainHost
{
    Param ([Parameter(Position=0, Mandatory=$True)] [string]$Host_To_Drain)

    $Host_To_Drain = Get-VMHost $Host_To_Drain

    $Hosts_In_Cluster = $Host_To_Drain.Parent | Get-VMHost


}

foreach($server in $servers) { DrainHost $server }