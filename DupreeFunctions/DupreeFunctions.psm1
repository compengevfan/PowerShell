Export-ModuleMember -Function *

New-Alias -Name cvc -Value Connect-vCenter -Scope Global -Force
New-Alias -Name svc -Value Show-vCenter -Scope Global -Force
New-Alias -Name redf -Value Import-DupreeFunctionsClean -Scope Global -Force