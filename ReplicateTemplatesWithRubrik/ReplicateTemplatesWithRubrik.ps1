[CmdletBinding()]
Param(
)

$ErrorActionPreference = "SilentlyContinue"
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false

#Import functions
. .\Functions\function_DoLogging
. .\Functions\function_Check-PowerCLI.ps1

$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "TemplateReplication@fanatics.com"
$emailTo = "TEAMEntCompute@fanatics.com","devops-engineering@fanatics.com"
$emailServer = "smtp.ff.p10"

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }

Check-PowerCLI

if (!(Get-Module -Name Rubrik)) { Import-Module Rubrik }

DoLogging -LogType Info -LogString "Please provide your credentials for connecting to Rubrik."
$RubrikCred = Get-Credential -Message "Please provide your credentials for connecting to Rubrik."

#If not connected to a vCenter, connect.
$ConnectedvCenter = $global:DefaultVIServers
if ($ConnectedvCenter.Count -eq 0)
{
    do
    {
        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) {  DoLogging -LogType Info -LogString "Attempting to connect to IAD vCenter..." }
        
        Connect-VIServer iad-vc001.fanatics.corp | Out-Null
        $ConnectedvCenter = $global:DefaultVIServers

        if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null){ DoLogging -LogType Warn -LogString "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
    } while ($ConnectedvCenter.Count -eq 0)
}

#Inform IEC and DevOps that template replication is starting.
$EmailBody = "All,`n`nPlease be advised that the template replication process has been started in the IAD vCenter. This means that templates beginning with 'TPL_' will be deleted and recreated. The process will not interrupt the creation of a VM (the delete command will wait until the template is not being used) but may prevent you from starting a VM creation request. Note that some sites might not get updated templates due to [reasons].`n`nAdditional emails will follow to provide progress updates.`n`nAny questions, comments, or concerns should be directed to Nik Whittington or Chris Dupree.`n`nThank you!!!"
Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Started!!!" -Priority High -body $EmailBody

DoLogging -LogType Info -LogString "Connecting to IAD Rubrik..."
Connect-Rubrik IAD-RUBK001 -Credential $RubrikCred | Out-Null
$RubrikClusterID = Invoke-RubrikRESTCall -Endpoint cluster/me -Method GET #gets the id of the current rubrik cluster
if ($RubrikClusterID -eq "" -or $RubrikClusterID -eq $null) { DoLogging -LogType Err -LogString "Connection to IAD Rubrik cluster failed!!! Script exiting"; exit }

#Get a list of all Template backup SLA's and create empty array for snapshot request data
DoLogging -LogType Info -LogString "Obtaining a list of all Gold Template SLAs..."
$SLAs = Get-RubrikSLA | where { $_.Name -like "Gold Templates*" } | Sort-Object Name
if ($SLAs -eq "" -or $SLAs -eq $null) { DoLogging -LogType Err -LogString "No template SLAs found on the IAD Rubrik!!! Script exiting"; exit }
$Snapshots = @()

#Kick off template backups
DoLogging -LogType Info -LogString "Creating manual backup jobs for each SLA..."
foreach ($SLA in $SLAs)
{
    $Snapshots += Get-RubrikVM -name TPL_GOLD_2K12R2 | where { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | New-RubrikSnapshot -SLA $($SLA.name) -Confirm:$false
    $Snapshots += Get-RubrikVM -name TPL_GOLD_2K8R2 | where { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | New-RubrikSnapshot -SLA $($SLA.name) -Confirm:$false
}

#Wait for all backups to complete
DoLogging -LogType Info -LogString "Waiting for manual backup jobs to complete..."
while($true)
{
    $Complete = $true
    foreach ($Snapshot in $Snapshots)
    {
        $Status = Invoke-RubrikRESTCall -Endpoint "vmware/vm/request/$($Snapshot.id)" -Method Get
        if ($Status.Status -ne "SUCCEEDED") { $Complete = $false }
    }

    if ($Complete) { break }
    Start-Sleep 30
}

#Create templates at IAD-Prod from the GOLD VMs
DoLogging -LogType Info -LogString "Backup jobs complete. Creating templates in IAD-PROD..."
$TplsForIAD = Get-Cluster IAD-Prod | Get-VM TPL_Gold*
foreach ($TplForIAD in $TplsForIAD)
{
    $TplName = ($TplForIAD.Name).replace("GOLD","IAD-PROD")
    if ((Get-Template $TplName) -ne $null)
    {
        DoLogging -LogType Info -LogString "Deleting $TplName..."
        Remove-Template $TplName -DeletePermanently -Confirm:$false
    }
    New-VM -VM $TplForIAD -Datastore $(Get-Datastore IAD-VS-DS01) -DiskStorageFormat Thick -Name $TplName -VMHost iad-vs01.fanatics.corp | Out-Null
    Get-VM $TplName | Set-VM -ToTemplate -Confirm:$false | Out-Null
    DoLogging -LogType Succ -LogString "IAD-PROD templates have been recreated and are ready for use."
    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Update..." -body "$TplName has been recreated and is ready for use."
}

#Create templates at IAD-DEVQC from the GOLD VMs
DoLogging -LogType Info -LogString "IAD-Prod templates created. Creating templates in IAD-DEVQC..."
foreach ($TplForIAD in $TplsForIAD)
{
    $TplName = ($TplForIAD.Name).replace("GOLD","IAD-DEVQC")
    if ((Get-Template $TplName) -ne $null)
    {
        DoLogging -LogType Info -LogString "Deleting $TplName..."
        Remove-Template $TplName -DeletePermanently -Confirm:$false
    }
    New-VM -VM $TplForIAD -Datastore $(Get-Datastore IAD-DEVQC-VS-DS01) -DiskStorageFormat Thick -Name $TplName -VMHost iad-devqc-vs01.fanatics.corp | Out-Null
    Get-VM $TplName | Set-VM -ToTemplate -Confirm:$false | Out-Null
    DoLogging -LogType Succ -LogString "IAD-DEVQC templates have been recreated and are ready for use."
    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Update..." -body "$TplName has been recreated and is ready for use."
}

#Gather all snapshot endpoints
DoLogging -LogType Info -LogString "Obtaining a list of snapshot endpoints..."
$Endpoints = @()
foreach ($Snapshot in $Snapshots)
{
    $Endpoints += Invoke-RubrikRESTCall -Endpoint "vmware/vm/request/$($Snapshot.id)" -Method Get
}

#Monitor for replication completion
DoLogging -LogType Info -LogString "Waiting for replication to complete..."
while($true)
{
    $Complete = $true
    foreach ($Endpoint in $Endpoints)
    {
        $EndpointID = $($EndPoint.links | where { $_.rel -eq "result" }).href.replace("https://iad-rubk001/api/v1/vmware/vm/snapshot/","")

        $Status = Invoke-RubrikRESTCall -Endpoint "vmware/vm/snapshot/$EndpointID" -Method Get
        if ($Status.replicationLocationIds -eq $null) { $Complete = $false }
    }

    if ($Complete) { break }
    Start-Sleep 60
}

DoLogging -LogType Info -LogString "Disconnecting from IAD Rubrik..."
Disconnect-Rubrik -Confirm:$false

DoLogging -LogType Info -LogString "Getting Rubrik to host to datastore mapping info..."
$DataFromFile = Import-Csv .\ReplicateTemplatesWithRubrik-Data.csv

#Export new VMs to convert to templates
foreach ($SLA in $SLAs)
{
    $RemoteRubrik = $($SLA.Name).replace("Gold Templates to ","")
    DoLogging -LogType Info -LogString "Connecting to $RemoteRubrik..."
    Connect-Rubrik $RemoteRubrik -Credential $RubrikCred | Out-Null
    $RemoteRubrikClusterID = Invoke-RubrikRESTCall -Endpoint cluster/me -Method GET #gets the id of the current rubrik cluster
    $Record = $DataFromFile | where { $_.RubrikDevice -eq "$RemoteRubrik" } #gets the proper information for the current Rubrik from the data file

    DoLogging -LogType Info -LogString "Issuing export task on $RemoteRubrik for 2K12R2 template..."
    $Replica = Get-RubrikVM TPL_GOLD_2K12R2 | where { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | Get-RubrikSnapshot | select -First 1 #gets the ID of the replicated snapshot using the rubrik cluster ID
    $ExportHost = $(Invoke-RubrikRESTCall -Endpoint vmware/host -Method Get).data | where { $_.name -eq "$($Record.Host)" -and $_.primaryClusterId -eq "$($RemoteRubrikClusterID.id)" } #gets the Rubrik ID of the host listed in the data file using the rubrik cluster ID
    $ExportDatastore = $ExportHost.datastores | where { $_.name -eq $($Record.Datastore) } #gets the Rubrik ID of the datastore listed in the data file from the exporthost info above
    $body = New-Object -TypeName PSObject -Property @{'hostId'=$($Exporthost.id);'datastoreId'=$($ExportDatastore.id)} #Assemble the POST payload for the REST API call
    Invoke-RubrikRESTCall -Endpoint vmware/vm/snapshot/$($Replica.id)/export -Method POST -Body $body | Out-Null #make rest api call to create an export job

    DoLogging -LogType Info -LogString "Issuing export task on $RemoteRubrik for 2K8R2 template..."
    $Replica = Get-RubrikVM TPL_GOLD_2K8R2 | where { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | Get-RubrikSnapshot | select -First 1 #gets the ID of the replicated snapshot using the rubrik cluster ID
    $ExportHost = $(Invoke-RubrikRESTCall -Endpoint vmware/host -Method Get).data | where { $_.name -eq "$($Record.Host)" -and $_.primaryClusterId -eq "$($RemoteRubrikClusterID.id)" } #gets the Rubrik ID of the host listed in the data file using the rubrik cluster ID
    $ExportDatastore = $ExportHost.datastores | where { $_.name -eq $($Record.Datastore) } #gets the Rubrik ID of the datastore listed in the data file from the exporthost info above
    $body = New-Object -TypeName PSObject -Property @{'hostId'=$($Exporthost.id);'datastoreId'=$($ExportDatastore.id)} #Assemble the POST payload for the REST API call
    Invoke-RubrikRESTCall -Endpoint vmware/vm/snapshot/$($Replica.id)/export -Method POST -Body $body | Out-Null #make rest api call to create an export job

    Disconnect-Rubrik -Confirm:$false
}

#Wait for exports to complete, power down, rename and convert to templates.
DoLogging -LogType Info -LogString "Starting export completion checks. Once a VM export is complete, the VM will be powered down, renamed and converted to template..."
while ($true)
{
    $Complete = $true
    foreach ($Site in $DataFromFile)
    {
        $LocalGoldCopies = Get-Cluster $($Site.Cluster) | Get-VM TPL_GOLD* | Sort-Object Name
        foreach ($LocalGoldCopy in $LocalGoldCopies)
        {
            $PowerState = $LocalGoldCopy.PowerState
            if ($PowerState -eq "PoweredOn") 
            {
                switch ($($LocalGoldCopy.GuestID))
                {
                    windows7Server64Guest { $ExistingTemplate = "TPL_$($Site.Cluster)_2K8R2";if ((Get-Template $ExistingTemplate) -ne $null) { DoLogging -LogType Info -LogString "Deleting $ExistingTemplate...";Remove-Template $ExistingTemplate -DeletePermanently -Confirm:$false } }
                    windows8Server64Guest { $ExistingTemplate = "TPL_$($Site.Cluster)_2K12R2";if ((Get-Template $ExistingTemplate) -ne $null) { DoLogging -LogType Info -LogString "Deleting $ExistingTemplate...";Remove-Template $ExistingTemplate -DeletePermanently -Confirm:$false } }
                }
                DoLogging -LogType Info -LogString "Converting '$($LocalGoldCopy.Name)' at '$($Site.Cluster)' to template..."
                DoLogging -LogType Info -LogString "Waiting for VMware tools to start..."
                $Ready = $false
                while (!($Ready))
                {
                    $ToolsStatus = (Get-VM -Name $($LocalGoldCopy.Name)).Guest.ExtensionData.ToolsStatus
                    if ($ToolsStatus -eq "toolsOK" -or $ToolsStatus -eq "toolsOld") { $Ready = $true }
                    Start-Sleep 5
                }
                Clear-Variable ToolsStatus
                DoLogging -LogType Info -LogString "Shutting down the VM..."
                Shutdown-VMGuest $($LocalGoldCopy.Name) -Confirm:$false | Out-Null
                while ($PowerState -eq "PoweredOn")
                {
                    Start-Sleep 5
                    $PowerState = (Get-VM $($LocalGoldCopy.Name)).PowerState
                }
                DoLogging -LogType Info -LogString "Renaming VM..."
                switch ($($LocalGoldCopy.GuestID))
                {
                    windows7Server64Guest { $NewName = "TPL_$($Site.Cluster)_2K8R2";$VMRenamed = Get-Cluster $($Site.Cluster) | Get-VM $($LocalGoldCopy.Name) | Set-VM -Name $NewName -Confirm:$false }
                    windows8Server64Guest { $NewName = "TPL_$($Site.Cluster)_2K12R2";$VMRenamed = Get-Cluster $($Site.Cluster) | Get-VM $($LocalGoldCopy.Name) | Set-VM -Name $NewName -Confirm:$false }
                }
                DoLogging -LogType Info -LogString "Converting to template..."
                Set-VM $VMRenamed -ToTemplate -Confirm:$false | Out-Null
                DoLogging -LogType Info -LogString "Continuing export completion checks..."
                Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Update..." -body "$VMRenamed template has been recreated and is ready for use."
            }
            else { $Complete = $false }
        }
    }

    if ($Complete) { break }
    Start-Sleep 60
}

DoLogging -LogType Succ -LogString "Template replication has completed successfully!!!"
$EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Completed!!!" -body $EmailBody
