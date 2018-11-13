$SnapinCheck = get-pssnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue

if ($SnapinCheck -eq $NULL)
{
 write-host ("Adding VMware Snapin...")
 add-pssnapin VMware.VimAutomation.Core
 write-host ("Complete")
}

$Data = Import-Csv "C:\Cloud\Dropbox\Scripts\PowerCLI\Work\RestoreCRIFVCCustomAttributes_Data.txt"

foreach ($VM in $Data)
{
	if (($VM.Product -ne "") -or ($VM.'Product Monitoring' -ne "") -or ($VM.'Reboot Order' -ne "") -or ($VM.'Replicate to PHL' -ne ""))
	{
		$CurrentVM = Get-VM -Name $VM.Name
		
		if ($VM.Product -ne "")
		{
			write-host ("Setting 'Product' Attribute on " + $CurrentVM.Name + ".")
			$CurrentVM | Set-CustomField -Name Product -Value $VM.Product
		}
		
		if ($VM.'Product Monitoring' -ne "")
		{
			write-host ("Setting 'Product Monitoring' Attribute on " + $CurrentVM.Name + ".")
			$CurrentVM | Set-CustomField -Name 'Product Monitoring' -Value $VM.'Product Monitoring'
		}
		
		if ($VM.'Reboot Order' -ne "")
		{
			write-host ("Setting 'Reboot Order' Attribute on " + $CurrentVM.Name + ".")
			$CurrentVM | Set-CustomField -Name 'Reboot Order' -Value $VM.'Reboot Order'
		}
		
		if ($VM.'Replicate to PHL' -ne "")
		{
			write-host ("Setting 'Replicate to PHL' Attribute on " + $CurrentVM.Name + ".")
			$CurrentVM | Set-CustomField -Name 'Replicate to PHL' -Value $VM.'Replicate to PHL'
		}
	}
	else 
	{
		write-host ($VM.Name + " has no attributes to set.")
	}
}