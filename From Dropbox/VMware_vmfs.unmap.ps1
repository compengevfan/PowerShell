##################################################
#Chris Redel | MOSERS | 02/11/2014
Clear-Host
#Notes:
#This script should grab all datastores presented to a specific ESXi host, and run the unmap
#	command on them sequentially with 5 minute breaks in between.
#
#Tested with PowerCLI 5.5
#KB Article: http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2057513
#Forum Post: https://communities.vmware.com/thread/436628
#PowerCLI Reference: https://www.vmware.com/support/developer/PowerCLI/index.html
#
## STUFF YOU MAY EDIT ############################
$pServer = "esx1"							#An ESXi servername or IP address in your environment
# You can use -SaveCredentials first to avoid having user and password info in this script, read below
# Connect-VIServer "Server" -User user -Password pass -SaveCredentials
$pUser = "username"							#user with sufficient privileges on $pServer, use "root" if you want
$pPwd = "password"							#password for $pUser
$pSleep = "300"								#time to sleep, in seconds, between unmap commands on Datastores. Default "300" (5 minutes)
$pCertAction = "Ignore"						#Action to take with Set-PowerCLIConfiguration -InvalidCertificateAction, default "Ignore"
$pSnapInName = "VMware.VimAutomation.Core"	#Name of PowerCLI snap-in, default "VMware.VimAutomation.Core"
##################################################
## DO NOT EDIT BELOW THIS LINE ###################

#Check PowerCLI snap-in, load if not already loaded
If ((Get-PSSnapin -Name $pSnapInName -ErrorAction SilentlyContinue) -eq $null ) {
	Add-PSSnapin $pSnapInName
}

#Set PowerCLI to ignore self-signed or invalid certificates
Set-PowerCLIConfiguration -InvalidCertificateAction $pCertAction

#Connect to an ESXi host
Connect-VIServer -Server $pServer -user $pUser -password $pPwd

#Store Get-EsxCli output
$pEsxCli = Get-EsxCli

#Get all datastore names
$pDSs = Get-Datastore #-Name "DSiso's"		#use -Name to specify a specific datastore, great for testing

#Loop all the datastores, run unmap on each, sleep between runs
ForEach ($pDS in $pDSs) {
	$pEsxCli.storage.vmfs.unmap($l,$pDS)		#Run unmap command
	Start-Sleep -s $pSleep						#Sleep before next run
	}