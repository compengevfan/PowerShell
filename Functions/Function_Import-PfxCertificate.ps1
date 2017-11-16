[cmdletbinding()]
param ($Servers = "ord-s05-web002")

function Import-PfxCertificate 
{
    param([String]$ServerName,[String]$pfxPass)
    $pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
 
    $pfx.import("G:\Dupree\StarDotFfDotP10.pfx",$pfxPass,“PersistKeySet”)

    $Personalstore = new-object System.Security.Cryptography.X509Certificates.X509Store("\\$ServerName\My","LocalMachine")
    $Personalstore.open(“MaxAllowed”)
    $Personalstore.add($pfx)
    $Personalstore.close()

    $Trustedstore = new-object System.Security.Cryptography.X509Certificates.X509Store("\\$ServerName\Root","LocalMachine")
    $Trustedstore.open(“MaxAllowed”)
    $Trustedstore.add($pfx)
    $Trustedstore.close()
}

foreach($server in $servers) { Import-PfxCertificate $server "O8aBKnnnaBTV"}