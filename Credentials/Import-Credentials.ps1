####################
#Import Credentials#
####################

Remove-Variable Credential-*

$ComputerName = $env:computername
#$UserName = $env:USERDOMAIN + "_" + $env:USERNAME

$CredFiles = Get-ChildItem $githome\Credentials\Credential-*.xml

foreach ($CredFile in $CredFiles) {
    New-Variable -Name $CredFile.BaseName -Value $(Import-Clixml $CredFile) -Scope Global
}