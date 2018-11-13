do
{
	Get-Date | Out-File c:\temp\Result.txt -append
	ping 192.168.1.36 | Out-File c:\temp\Result.txt -append
}
while (1 -eq 1)