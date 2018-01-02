Function ConvertToDN
{
    Param(
        [Parameter(Mandatory=$true)] [string] $Domain,
        [Parameter(Mandatory=$true)] [string] $OUPath
    )

    $DN = ""

    $OUPath.Split('/') | foreach { $DN = "OU=" + $_ + "," + $DN }
    $Domain.Split('.') | foreach { $DN = $DN + "DC=" + $_ + "," }

    $DN = $DN.Substring(0,$DN.Length - 1)

    return $DN
}