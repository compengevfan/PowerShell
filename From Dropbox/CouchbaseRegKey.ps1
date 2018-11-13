[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True)] [string]$Site
)


switch ($Site){
    "JAX" {write-host "Retrieving VM list...";$VMs = Get-Cluster JAX-Prod-* | Get-VM | Where-Object {$_.Name -notlike "*CLS*" -and $_.Guest.OSFullName -like "*Windows*" -and $_.PowerState -eq "PoweredOn"}}
    "ORD" {write-host "Retrieving VM list...";$VMs = Get-DataCenter ORD | Get-VM | Where-Object {$_.Name -notlike "*CLS*" -and $_.Guest.OSFullName -like "*Windows*" -and $_.PowerState -eq "PoweredOn"}}
    default {write-host "Site is not valid. Please enter JAX or ORD."; exit}
}

$NumberOfServers = $VMs.Count
$i = 1

foreach ($VM in $VMs){
    Write-Progress -Activity "Processing Servers" -status "Checking Server $i of $NumberOfServers" -percentComplete ($i / $NumberOfServers*100)
    
    Set-RegDWord -Data 60000 -Key SYSTEM\CurrentControlSet\services\Tcpip\Parameters -Value KeepAliveTime -ComputerName $VM.Name -ErrorAction SilentlyContinue -Confirm:$false
    
    $KeepAlive = Get-RegValue -ComputerName $VM.Name -Key SYSTEM\CurrentControlSet\services\Tcpip\Parameters -Value KeepAliveTime -ErrorAction SilentlyContinue

    if ($KeepAlive.Data -ne 60000) {Write-Host $VM.Name did not update}
    $i++
}