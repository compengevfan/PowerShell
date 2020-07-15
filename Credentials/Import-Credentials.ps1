####################
#Import Credentials#
####################

Remove-Variable Credential-*

$ComputerName = $env:computername
$UserName = $env:USERDOMAIN + "_" + $env:USERNAME

$CredFile = Get-ChildItem .\Credential-$UserName-$ComputerName.xml

New-Variable -Name $($CredFile.BaseName) -Value $(Import-Clixml $CredFile) -Scope Global
