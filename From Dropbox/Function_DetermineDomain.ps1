[cmdletbinding()] 
Param ( 
    $servers = "DEV-DB-SQL011"

) 

Function DetermineDomain
{
    Param ([Parameter(Position=0, Mandatory=$True, ValueFromPipeline=$True)] [string]$ServerName)

	$Domains = @{
		".footballfanatics.wh" = "FF"
		".fanatics.corp" = "FAN"
		".ff.p10" = "P10"
	}

    foreach ($Domain in $Domains.Keys)
    {
        $FQDN = $ServerName + $Domain
        $Check = Test-Connection "$FQDN" -Count 1 -ErrorAction SilentlyContinue

        if ($Check -ne $NULL) { $RetDomain = $Domain }
    }

    #Catch not found
    if ($RetDomain -eq $NULL) { $RetDomain = "DNE" }

    Return $RetDomain
}

foreach($server in $servers) { DetermineDomain $server }