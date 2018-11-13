$CheckDelay = 5

$Servers = @("FROW-PS001", "FROW-PS101")

foreach ($Server in $Servers)
{
    $VM = Get-VM $Server

    Shutdown-VMGuest -VM $VM -Confirm:$false

    $NotOffYet = "true"

    while ($NotOffYet -eq "true") 
    {
	    start-sleep -s $CheckDelay
	    $NotOffYet = "false"
	    $Check = (Get-VM -Name $VM | select PowerState)
	    if ($Check.PowerState -eq "PoweredOn")
		    {
			    $NotOffYet = "true"
		    }
	    Write-Host ""
	    Write-Host "VM shut down not complete..."
    }

    Set-VM -VM $VM -NumCPU 4 -Confirm:$false
}