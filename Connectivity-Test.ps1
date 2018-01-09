[CmdletBinding()]
Param(
)

$i = 1

cd g:\jobs

while ($i -le 60)
{
    Get-Date | Out-File .\ConnectivityTest.txt -Append

    Clear-DnsClientCache 

    "Checking DNS" | Out-File .\ConnectivityTest.txt -Append

    $DNSCheck = Resolve-DnsName jax-osvc103.ff.p10

    if ($DNSCheck -ne $null) {$DNSCheck | Out-File .\ConnectivityTest.txt -Append; "Checking ping" | Out-File .\ConnectivityTest.txt -Append; Test-Connection jax-osvc103.ff.p10 | Out-File .\ConnectivityTest.txt -Append }

    Clear-Variable DNSCheck

    Start-Sleep 60
    $i++
}