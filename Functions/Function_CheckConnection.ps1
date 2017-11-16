[cmdletbinding()] 
Param ( 
    $servers = "DEV-DB-SQL011"

) 

Function CheckConnection
{
    
}

foreach($server in $servers) { CheckConnection $server }