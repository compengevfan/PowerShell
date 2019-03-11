Import-Module Posh-SSH

$cred = Get-Credential

New-SSHSession -ComputerName 10.92.238.99 -Credential $cred
New-SSHSession -ComputerName 10.92.238.100 -Credential $cred

$Info = $(Invoke-SSHCommand -SessionId 0 -Command "version").Output | ConvertFrom-String -Delimiter ":"
$Info | ForEach-Object { $_.P2 = ($_.P2).trim() }

$Switch1 = $(Invoke-SSHCommand -SessionId 0 -Command "switchshow").Output
$Switch2 = Invoke-SSHCommand -SessionId 1 -Command "cfgshow" 


Remove-SSHSession -SessionId 0
Remove-SSHSession -SessionId 1
