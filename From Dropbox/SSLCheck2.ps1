[CmdletBinding()]
Param(
   [Parameter(Position = 0, Mandatory=$True, ValueFromPipeline=$True)] $Domain
)

$FunctionCheck = Get-ChildItem function:\ | ?{$_.Name -eq "RetrieveAllDomainServers"}

if($FunctionCheck -eq $null){write-host "RetrieveAllDomainServers function does not exist. Exiting.";exit}

$Servers = RetrieveAllDomainServers $Domain

if($Servers -ne $null)
{
    $ServerCount = $Servers.Count
    $i = 1

    $Output = @()

    foreach ($Server in $Servers)
    {
        $ServerName = $Server.Name
        Write-Verbose "Processing Server: $Servername"
        Write-Progress -Activity "Processing Servers" -status "Checking Server $i of $ServerCount" -percentComplete ($i / $ServerCount*100)

        $ConnCheck = Test-Connection $ServerName -Count 1 -ErrorAction SilentlyContinue

        if ($ConnCheck -ne $null)
        {
            $Bindings = Get-WmiObject -Namespace "root\WebAdministration" -Class SSLBinding -ComputerName $ServerName -Authentication 6 -ErrorAction SilentlyContinue | ?{$_.CertificateHash -eq "2492B5FB14327C608EB763AFA951AA33C3218DBB"}
            if ($Bindings -ne $null)
            {
                foreach ($Binding in $Bindings)
                {
                    $Output += New-Object psobject -Property @{
                    ComputerName = $ServerName
                    IPAddress = $Binding.IPAddress
                    Port = $Binding.Port
                    }
                }
            }
            else {Write-Output "$ServerName did not respong to WMI call." | Out-File -FilePath .\SSLWMIFailed.txt -Append}
        }
        else {write-output "$ServerName did not respond to ping." | Out-File -FilePath .\SSLPingFailed.txt -Append}
        $i++
    }

    $Output | Select-Object ComputerName,IPAddress,Port | Export-Csv ".\SSL.txt"
}