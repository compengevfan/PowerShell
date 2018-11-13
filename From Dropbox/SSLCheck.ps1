[CmdletBinding()]
Param(
   [Parameter(Position = 0, Mandatory=$True, ValueFromPipeline=$True)] $Servers
)

$ServerCount = $Servers.Count
$i = 1

$Output = @()

foreach ($Server in $Servers){
    $ServerName = $Server.Name
    Write-Verbose "Processing Server: $Servername"
    Write-Progress -Activity "Processing Servers" -status "Checking Server $i of $ServerCount" -percentComplete ($i / $ServerCount*100)

    $ConnCheck = Test-Connection $ServerName -Count 1 -ErrorAction SilentlyContinue

    if ($ConnCheck -ne $null){
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$ServerName\My","LocalMachine")

        $store.Open("ReadOnly")

        $CertCheck = $store.Certificates | ?{$_.Thumbprint -eq "2492B5FB14327C608EB763AFA951AA33C3218DBB"}

        if ($CertCheck -ne $null){
            $Output += New-Object psobject -Property @{
            ComputerName = $ServerName
            }
        }
    }
    else {
        write-host "$ServerName could not be contacted."
    }
    $i++
}

$Output | Select-Object ComputerName | Export-Csv ".\SSL.txt"