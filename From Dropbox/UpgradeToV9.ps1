$VMs = Get-VM

foreach ($VM in $VMs)
{
	$VersionCap = $VM.Version
	if ($VersionCap -eq "v8")
	{
		Shutdown-VMGuest $VM -Confirm:$false
		
		$NotOffYet = "true"

		while ($NotOffYet -eq "true") 
		{
			start-sleep -s 10
			$NotOffYet = "false"
			ForEach ($VM in $WorkGroup)
			{
				$Check = (Get-VM -Name $VM | select PowerState)
				if ($Check.PowerState -eq "PoweredOn")
					{
						$NotOffYet = "true"
					}
			}
			Write-Host ""
			Write-Host "VM shut down not complete..."
		}
		
		start-sleep -s 10
		
		Set-VM -VM $VM -Version v9 -Confirm:$false
		
		start-sleep -s 10
		
		Start-VM $VM -Confirm:$false
	}

}