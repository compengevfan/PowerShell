#Script take in list of servers in CompellentiSCSIRegUpdateData.txt in the working directory. Sets MPIO and Microsoft iSCSI adapter reg key values according to Compellent best practices.

$Servers = Get-Content .\CompellentiSCSIRegUpdateData.txt

foreach ($Server in $Servers)
{
	write-host $Server -foregroundcolor "Green"
	$ConnectivityCheck = Test-Connection $Server -Count 1 -ErrorAction SilentlyContinue
	
	if ($ConnectivityCheck -ne $NULL)
	{	
		#MPIO
		
		$MPIO1 = Get-RegValue -ComputerName $Server -Key System\CurrentControlSet\Services\mpio\Parameters -Value PDORemovePeriod -ErrorAction SilentlyContinue
		
		if ($MPIO1 -eq $NULL)
		{
			write-host "Does not have MPIO." -foregroundcolor "Yellow"
		}
		else
		{
			$MPIO2 = Get-RegValue -ComputerName $Server -Key System\CurrentControlSet\Services\mpio\Parameters -Value PathRecoveryInterval
			$MPIO3 = Get-RegValue -ComputerName $Server -Key System\CurrentControlSet\Services\mpio\Parameters -Value UseCustomPathRecoveryInterval

			$MPIOPDORemove = $MPIO1.Data
			$MPIOPathRecovery = $MPIO2.Data
			$MPIOCustomPath = $MPIO3.Data

			if ($MPIOPDORemove -ne 90)
			{
				Set-RegDWord -ComputerName $Server -Key System\CurrentControlSet\Services\mpio\Parameters -Value PDORemovePeriod -Data 90 -Confirm:$false
			}

			if ($MPIOPathRecovery -ne 30)
			{
				Set-RegDWord -ComputerName $Server -Key System\CurrentControlSet\Services\mpio\Parameters -Value PathRecoveryInterval -Data 30 -Confirm:$false
			}

			if ($MPIOCustomPath -ne 1)
			{
				Set-RegDWord -ComputerName $Server -Key System\CurrentControlSet\Services\mpio\Parameters -Value UseCustomPathRecoveryInterval -Data 1 -Confirm:$false
			}
		}
		#iSCSI
		$iSCSIKeys = Get-RegKey -ComputerName $Server -Key "SYSTEM\CurrentControlSet\Control\Class\{4D36E97B-E325-11CE-BFC1-08002BE10318}" -Name 0*
		foreach ($iSCSIKey in $iSCSIKeys)
		{
			$iSCSIValue = Get-RegValue -ComputerName $Server -Key $iSCSIKey.Key -Value DriverDesc
			if ($iSCSIValue.Data -like "Microsoft iSCSI*")
			{
				$CorrectKey = $iSCSIKey.Key + "\Parameters"
				$ISCSIO1 = Get-RegValue -ComputerName $Server -Key $CorrectKey -Value MaxRequestHoldTime
				$ISCSIO2 = Get-RegValue -ComputerName $Server -Key $CorrectKey -Value LinkDownTime
				
				$ISCSIMaxRequestHold = $ISCSIO1.Data
				$ISCSILinkDown = $ISCSIO2.Data
				
				if ($ISCSIMaxRequestHold -ne 90)
				{
					Set-RegDWord -ComputerName $Server -Key $CorrectKey -Value MaxRequestHoldTime -Data 90 -Confirm:$false
				}
				
				if ($ISCSILinkDown -ne 45)
				{
					Set-RegDWord -ComputerName $Server -Key $CorrectKey -Value LinkDownTime -Data 45 -Confirm:$false
				}
			}
		}
	}
}