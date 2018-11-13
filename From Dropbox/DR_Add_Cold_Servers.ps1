$ColdHosts = Import-Csv "C:\scripts\DR_Add_Cold_Servers_Data.csv"

ForEach ($ColdHost in $ColdHosts)
{
	write-host("Processing server: " + $ColdHost.Name)
	Add-VMHost $ColdHost.Name -Location Cold -user root -password $Password -Force
}