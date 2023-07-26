[CmdletBinding()]
Param(
)

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

#$ErrorActionPreference = "SilentlyContinue"
 
Function Check-PowerCLI
{
    Param(
    )
 
    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
        write-host ("Adding PowerCLI...")
        Get-Module -Name VMware* -ListAvailable | Import-Module -Global
        write-host ("Loaded PowerCLI.")
    }
}
 
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
 
Check-PowerCLI
 
if ($null -ne $CredFile)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}
 
Connect-DFvCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

##################
#Email Variables
##################
#emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "TemplateReplication@fanatics.com"
#$emailTo = "cdupree@fanatics.com"
$emailTo = "TEAMEntCompute@fanatics.com"
$emailServer = "smtp.ff.p10"

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File."
try { $DataFromFile = ConvertFrom-JSON (Get-Content ".\ReplicateTemplatesWithRubrik-Data.json" -raw) -ErrorAction Stop }
catch { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "JSON Import failed!!!`n`rError encountered is:`n`r$($Error[0])`n`rScript Exiting!!!"; exit }

#List of OS Codes.
$OSes = $DataFromFile.OSCodes

#Generate List of Template Names
$TemplateNames = @()
foreach ($OSCode in $OSes) { $TemplateNames += "TPL_GOLD_$($OSCode.OSCode)" }

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking for Rubrik PS Module..."
if (Get-Module -ListAvailable -Name Rubrik)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Importing Rubrik PS module..."
    Import-Module Rubrik
}
else
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Rubrik PS Module is missing!!! Script exiting!!!"
    exit
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining Rubrik credentials."
$RubrikCred = Get-Credential -Message "Please provide credentials for connecting to Rubrik. Note these credentials will be used to connect to all Rubrik devices."

##################
#Begin: Environment and sanity checks
##################

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Beginning environment and sanity checks. Please wait for this to complete."
Read-Host "Press 'Enter' to continue..."

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying IAD-PROD info..."
$IADInfo = $DataFromFile.IADPROD
try
{
    Get-Cluster $($IADInfo.Cluster) | Get-VMHost $($IADInfo.Host) -ErrorAction Stop | Out-Null
    Get-VMHost $($IADInfo.Host) | Get-Datastore $($IADInfo.Datastore) -ErrorAction Stop | Out-Null
    $Folders = Get-Datacenter $($IADInfo.Datacenter) | Get-Folder "Templates" -ErrorAction Stop | Out-Null
    if ($Folders.Count -gt 1) { throw "Too Many Folders" }
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Host, Datastore and Folder located."
}
catch
{
    if ($Error[0] -like "*Get-VMHost*") { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "IAD-PROD host is incorrect!!! Script Exiting!!!" }
    if ($Error[0] -like "*Get-Datastore*") { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "IAD-PROD datastore is incorrect!!! Script Exiting!!!" }
    if ($Error[0] -like "*Get-Folder*") { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "IAD datacenter does not have a 'Templates' folder!!! Script Exiting!!!" }
    if ($Error[0].Exception.tostring() -like "*Too Many Folders") { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Multiple templates folders found in $($IADInfo.Datacenter) Datacenter!!! Script exiting!!!" }
    exit
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying GOLD VMs exist..."
foreach ($TemplateName in $TemplateNames)
{
    try
    {
        Get-Cluster $($IADInfo.Cluster) | Get-VM $TemplateName -ErrorAction Stop | Out-Null
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "$TemplateName found."
    }
    catch
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "$TemplateName not found!!! Error encountered is:`n`r$($Error[0])`n`rScript exiting!!!"
        exit
    }
}

$RemoteRubriks = $DataFromFile.RubrikInfo | Where-Object {$_.Enable -eq "Yes"}
foreach ($RemoteRubrik in $RemoteRubriks)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking connection to $($RemoteRubrik.RubrikDevice)..."
    try
    {
        Connect-Rubrik $($RemoteRubrik.RubrikDevice) -Credential $RubrikCred | Out-Null
        $RubrikClusterID = Invoke-RubrikRESTCall -Endpoint cluster/me -Method GET #gets the id of the current rubrik cluster
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Connection to $($RemoteRubrik.RubrikDevice) successful."
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Storing the Rubrik ID..."
        $RemoteRubrik.ID = $RubrikClusterID.id
        Disconnect-Rubrik -Confirm:$false
    }
    catch
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Connection to $($RemoteRubrik.RubrikDevice) failed!!! Error encountered is:`n`r$($Error[0])`n`rScript exiting!!!"
        exit
    }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying cluster $($RemoteRubrik.Cluster)..."
    try
    {
        Get-Cluster $($RemoteRubrik.Cluster) -ErrorAction Stop | Out-Null
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Cluster $($RemoteRubrik.Cluster) is valid."
    }
    catch
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Cluster $($RemoteRubrik.Cluster) is invalid!!! Script exiting!!!"
        exit
    }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying host $($RemoteRubrik.Host)..."
    try
    {
        Get-VMHost $($RemoteRubrik.Host) -ErrorAction Stop | Out-Null
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Host $($RemoteRubrik.Host) is valid."
    }
    catch
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Host $($RemoteRubrik.Host) is invalid!!! Script exiting!!!"
        exit
    }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying datastore $($RemoteRubrik.Datastore)..."
    try
    {
        Get-Datastore $($RemoteRubrik.Datastore) -ErrorAction Stop | Out-Null
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Datastore $($RemoteRubrik.Datastore) is valid"
    }
    catch
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Datastore $($RemoteRubrik.Datastore) is invalid!!! Script exiting!!!"
        exit
    }

    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying 'Templates' folder..."
    try
    {
        $Folders = Get-Datacenter $($RemoteRubrik.Datacenter) | Get-Folder "Templates"
        if ($Folders.Count -gt 1) { throw "Too Many Folders" }
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Templates folder located."
    }
    catch
    {
        if ($Error[0].Exception.tostring() -like "*Too Many Folders") { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Multiple templates folders found in $($RemoteRubrik.Datacenter) Datacenter!!! Script exiting!!!" }
        else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Templates folder not found in $($RemoteRubrik.Datacenter) Datacenter!!! Script exiting!!!" }
        exit
    }
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking connection to IAD Rubrik..."
try
{
    Connect-Rubrik $($IADInfo.RubrikDevice) -Credential $RubrikCred | Out-Null
    $RubrikClusterID = Invoke-RubrikRESTCall -Endpoint cluster/me -Method GET #gets the id of the current rubrik cluster
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Connection to IAD Rubrik successful."
}
catch
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Connection to IAD Rubrik cluster failed!!! Script exiting"
    exit
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking to make sure all enabled Rubriks have an SLA with the correct replication target..."
foreach ($RemoteRubrik in $RemoteRubriks)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying SLA for $($RemoteRubrik.RubrikDevice)..."
    $SLA = Get-RubrikSLA | Where-Object { $_.Name -eq "Gold Templates to $($RemoteRubrik.RubrikDevice)" }
    if ($null -eq $SLA)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "IAD Rubrik does not have an SLA for $($RemoteRubrik.RubrikDevice)!!! Script exiting!!!"
        exit
    }
    else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "SLA for $($RemoteRubrik.RubrikDevice) found." }
    
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying replication target..."
    if ($SLA.replicationSpecs.locationId -ne $RemoteRubrik.ID)
    {
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "SLA replication target is incorrect!!! Script exiting!!!"
        exit
    }
    else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "SLA replicaiton target verified." }
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Environment and sanity checks completed successfully. Starting the replication process which could take several hours."
Read-Host "Press 'Enter' to continue..."

##################
#End: Environment and sanity checks
##################

#Inform IEC and DevOps that template replication is starting.
$EmailBody = "All,`n`nPlease be advised that the template replication process has been started in the IAD vCenter. This means that templates beginning with 'TPL_' will be deleted and recreated. The process will not interrupt the creation of a VM (the delete command will wait until the template is not being used) but may prevent you from starting a VM creation request. Note that some sites might not get updated templates due to [reasons].`n`nAdditional emails will follow to provide progress updates.`n`nAny questions, comments, or concerns should be directed to Nik Whittington or Chris Dupree.`n`nThank you!!!"
Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Started!!!" -Priority High -body $EmailBody

$Snapshots = @()

#Kick off template backups
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating manual backup jobs for each SLA..."
foreach ($RemoteRubrik in $RemoteRubriks)
{
    foreach ($TemplateName in $TemplateNames)
    {
        $Snapshots += New-Object -Type PSObject -Property (@{
            id = $(Get-RubrikVM -name $TemplateName | Where-Object { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | New-RubrikSnapshot -SLA "Gold Templates to $($RemoteRubrik.RubrikDevice)" -Confirm:$false).id
            Rubrik = $($RemoteRubrik.RubrikDevice)
            Template = $TemplateName
            BackupComplete = "Not Complete"})
    }
}

#Wait for all backups to complete
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for manual backup jobs to complete..."
while($true)
{
    Clear-Host
    foreach ($Snapshot in $Snapshots)
    {
        $Status = Invoke-RubrikRESTCall -Endpoint "vmware/vm/request/$($Snapshot.id)" -Method Get
        if ($Status.Status -eq "SUCCEEDED") { $Snapshot.BackupComplete = "Complete" }
    }

    if (!($Snapshots.BackupComplete -eq "Not Complete")) { break }

    Write-Host "Script has been running since $ScriptStarted."
    Write-Host "Backup status at $(Get-Date -Format MM-dd-yyyy_HH-mm-ss)`r`n"
    foreach ($Snapshot in $Snapshots)
    {
        if ($($Snapshot.BackupComplete) -eq "Complete") { Write-Host "$($Snapshot.Rubrik) - $($Snapshot.Template) --> $($Snapshot.BackupComplete)" -ForegroundColor Green }
        else { Write-Host "$($Snapshot.Rubrik) - $($Snapshot.Template) --> $($Snapshot.BackupComplete)" }
    }
    Start-Sleep 30
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Backup jobs complete."

if ($($IADInfo.Enable) -eq "yes")
{
    #Create templates at IAD-Prod from the GOLD VMs
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating templates in IAD-PROD..."
    foreach ($TemplateName in $TemplateNames)
    {
        $TplName = $TemplateName.replace("GOLD","IAD-PROD")
        if ($null -ne (Get-Template $TplName -ErrorAction SilentlyContinue))
        {
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Deleting $TplName..."
            Remove-Template $TplName -DeletePermanently -Confirm:$false | Out-Null
        }
        New-VM -VM $TemplateName -Datastore $(Get-Datastore $($IADInfo.Datastore)) -DiskStorageFormat Thick -Name $TplName -VMHost $($IADInfo.Host) | Out-Null
        $ConvertedToTemplate = Set-VM $TplName -ToTemplate -Confirm:$false
        Move-Template -Template $ConvertedToTemplate -Destination $(Get-Datacenter $($IADInfo.Datacenter) | Get-Folder "Templates")
        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "$TplName has been recreated and is ready for use."
        Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Update..." -body "$($TplName.Name) has been recreated and is ready for use."
    }
}
else { Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Skipping IAD template creation..." }

#Gather all snapshot endpoints
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining a list of snapshot endpoints..."
$Endpoints = @()
foreach ($Snapshot in $Snapshots)
{
    $Endpoints += New-Object -Type PSObject -Property (@{
        id = ($(Invoke-RubrikRESTCall -Endpoint "vmware/vm/request/$($Snapshot.id)" -Method Get).links | Where-Object { $_.rel -eq "result" }).href.replace("https://iad-rubk001/api/v1/vmware/vm/snapshot/","")
        Rubrik = $Snapshot.Rubrik
        Template = $Snapshot.Template
        ReplicationComplete = "Not Complete"})
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Exporting Snapshot information to file..."
$Endpoints | Select-Object Rubrik, Template, @{Name="Endpoint ID";Expression={$_.id}} | Out-File .\~Logs\"$ScriptName $ScriptStarted.debug" -append

#Monitor for replication completion
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for replication to complete..."
while($true)
{
    Clear-Host
    foreach ($Endpoint in $Endpoints)
    {
        $Status = Invoke-RubrikRESTCall -Endpoint "vmware/vm/snapshot/$($Endpoint.ID)" -Method Get
        if ($null -ne $Status.replicationLocationIds) { $Endpoint.ReplicationComplete = "Complete" }
    }

    if (!($Endpoints.ReplicationComplete -eq "Not Complete")) { break }

    Write-Host "Script has been running since $ScriptStarted."
    Write-Host "Replication status at $(Get-Date -Format MM-dd-yyyy_HH-mm-ss)`r`n"
    foreach ($Endpoint in $Endpoints)
    {
        if ($($Endpoint.ReplicationComplete) -eq "Complete") { Write-Host "$($Endpoint.Rubrik) - $($Endpoint.Template) --> $($Endpoint.ReplicationComplete)" -ForegroundColor Green }
        else { Write-Host "$($Endpoint.Rubrik) - $($Endpoint.Template) --> $($Endpoint.ReplicationComplete)" }
    }
    Start-Sleep 60
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Disconnecting from IAD Rubrik..."
Disconnect-Rubrik -Confirm:$false

#Export new VMs to convert to templates
foreach ($RemoteRubrik in $RemoteRubriks)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Connecting to $($RemoteRubrik.RubrikDevice)..."
    Connect-Rubrik $($RemoteRubrik.RubrikDevice) -Credential $RubrikCred | Out-Null

    foreach ($TemplateName in $TemplateNames)
    {
        try
        {
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Issuing export task on $($RemoteRubrik.RubrikDevice) for $TemplateName..."
            $Replica = Get-RubrikVM $TemplateName | Where-Object { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | Get-RubrikSnapshot | Select-Object -First 1 #gets the ID of the replicated snapshot using the rubrik cluster ID
            $ExportHost = $(Invoke-RubrikRESTCall -Endpoint vmware/host -Method Get).data | Where-Object { $_.name -eq "$($RemoteRubrik.Host)" -and $_.primaryClusterId -eq "$($RemoteRubrik.ID)" } #gets the Rubrik ID of the host listed in the data file using the rubrik cluster ID
            $ExportDatastore = $ExportHost.datastores | Where-Object { $_.name -eq $($RemoteRubrik.Datastore) } #gets the Rubrik ID of the datastore listed in the data file from the exporthost info above
            $body = New-Object -TypeName PSObject -Property @{'hostId'=$($Exporthost.id);'datastoreId'=$($ExportDatastore.id)} #Assemble the POST payload for the REST API call
            Invoke-RubrikRESTCall -Endpoint vmware/vm/snapshot/$($Replica.id)/export -Method POST -Body $body | Out-Null #make rest api call to create an export job
        }
        catch
        {
            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Error encountered while creating export tasks:`n`r$($Error[0])`n`rScript Exiting!!!"
            exit
        }
    }

    Disconnect-Rubrik -Confirm:$false
}

#Wait for exports to complete, power down, rename and convert to templates.
Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Starting export completion checks. Once a VM export is complete, the VM will be powered down, renamed and converted to template..."
while ($true)
{
    $Complete = $true
    foreach ($RemoteRubrik in $RemoteRubriks)
    {
        $LocalGoldCopies = Get-Cluster $($RemoteRubrik.Cluster) | Get-VM TPL_GOLD*
        foreach ($LocalGoldCopy in $LocalGoldCopies)
        {
            $PowerState = $LocalGoldCopy.PowerState
            if ($PowerState -eq "PoweredOn") 
            {
                foreach($TemplateName in $TemplateNames)
                {
                    if ($LocalGoldCopy.Name -like "$TemplateName*") 
                    {
                        $TemplateNameModified = $TemplateName.Replace("GOLD", $($RemoteRubrik.Cluster))

                        if ($null -ne (Get-Template $TemplateNameModified -ErrorAction SilentlyContinue))
                        {
                            Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Deleting $TemplateNameModified..."
                            Remove-Template $TemplateNameModified -DeletePermanently -Confirm:$false
                        }

                        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Converting '$($LocalGoldCopy.Name)' at '$($RemoteRubrik.Cluster)' to template..."
                        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for VMware tools to start..."
                        $Ready = $false
                        while (!($Ready))
                        {
                            $ToolsStatus = (Get-VM -Name $($LocalGoldCopy.Name)).Guest.ExtensionData.ToolsStatus
                            if ($ToolsStatus -eq "toolsOK" -or $ToolsStatus -eq "toolsOld") { $Ready = $true }
                            Start-Sleep 5
                        }
                        Clear-Variable ToolsStatus
                        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down the VM..."
                        Shutdown-VMGuest $($LocalGoldCopy.Name) -Confirm:$false | Out-Null
                        while ($PowerState -eq "PoweredOn")
                        {
                            Start-Sleep 5
                            $PowerState = (Get-VM $($LocalGoldCopy.Name)).PowerState
                        }
                        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Renaming VM..."
                        $VMRenamed = Get-Cluster $($RemoteRubrik.Cluster) | Get-VM $($LocalGoldCopy.Name) | Set-VM -Name $TemplateNameModified -Confirm:$false
                        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Converting to template..."
                        $VMConverted = Set-VM $VMRenamed -ToTemplate -Confirm:$false
                        Move-Template -Template $VMConverted -Destination $(Get-Datacenter $($RemoteRubrik.Datacenter) | Get-Folder "Templates")
                        Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Continuing export completion checks..."
                        Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Update..." -body "$($VMRenamed.Name) template has been recreated and is ready for use."
                    }
                }
            }
            else { $Complete = $false }
        }
    }

    if ($Complete) { break }
    Start-Sleep 60
}

Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Template replication has completed successfully!!!"
$EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Completed!!!" -body $EmailBody
