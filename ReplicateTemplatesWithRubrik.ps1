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
 
Connect-vCenter -vCenter $vCenter -vCenterCredential $Credential_To_Use

##################
#Email Variables
##################
#emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "TemplateReplication@fanatics.com"
#$emailTo = "cdupree@fanatics.com"
$emailTo = "TEAMEntCompute@fanatics.com"
$emailServer = "smtp.ff.p10"

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing JSON Data File."
try { $DataFromFile = ConvertFrom-JSON (Get-Content ".\ReplicateTemplatesWithRubrik-Data.json" -raw) -ErrorAction SilentlyContinue }
catch { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "JSON Import failed!!!`n`rError encountered is:`n`r$($Error[0])`n`rScript Exiting!!!"; exit }

#List of OS Codes.
$OSes = $DataFromFile.OSCodes

#Generate List of Template Names
$TemplateNames = @()
foreach ($OSCode in $OSes) { $TemplateNames += "TPL_GOLD_$($OSCode.OSCode)" }

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking for Rubrik PS Module..."
if (Get-Module -ListAvailable -Name Rubrik)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Importing Rubrik PS module..."
    Import-Module Rubrik
}
else
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Rubrik PS Module is missing!!! Script exiting!!!"
    exit
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining Rubrik credentials."
$RubrikCred = Get-Credential -Message "Please provide credentials for connecting to Rubrik. Note these credentials will be used to connect to all Rubrik devices."

##################
#Begin: Environment and sanity checks
##################

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Beginning environment and sanity checks. Please wait for this to complete."
Read-Host "Press 'Enter' to continue..."

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying IAD-PROD info..."
$IADInfo = $DataFromFile.IADPROD
try
{
    Get-Cluster $($IADInfo.Cluster) | Get-VMHost $($IADInfo.Host) -ErrorAction Stop | Out-Null
    Get-VMHost $($IADInfo.Host) | Get-Datastore $($IADInfo.Datastore) -ErrorAction Stop | Out-Null
    Get-Datacenter $($IADInfo.Datacenter) | Get-Folder "Templates" -ErrorAction Stop | Out-Null
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Host, Datastore and Folder located."
}
catch
{
    if ($Error[0] -like "*Get-VMHost*") { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "IAD-PROD host is incorrect!!! Script Exiting!!!" }
    if ($Error[0] -like "*Get-Datastore*") { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "IAD-PROD datastore is incorrect!!! Script Exiting!!!" }
    if ($Error[0] -like "*Get-Folder*") { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "IAD datacenter does not have a 'Templates' folder!!! Script Exiting!!!" }
    exit
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying GOLD VMs exist..."
foreach ($TemplateName in $TemplateNames)
{
    try
    {
        Get-Cluster $($IADInfo.Cluster) | Get-VM $TemplateName -ErrorAction SilentlyContinue | Out-Null
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "$TemplateName found."
    }
    catch
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "$TemplateName not found!!! Error encountered is:`n`r$($Error[0])`n`rScript exiting!!!"
        exit
    }
}

$Rubriks = $DataFromFile.RubrikInfo | Where-Object {$_.Enable -eq "Yes"}
foreach ($Rubrik in $Rubriks)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking connection to $($Rubrik.RubrikDevice)..."
    try
    {
        Connect-Rubrik $($Rubrik.RubrikDevice) -Credential $RubrikCred | Out-Null
        $RubrikClusterID = Invoke-RubrikRESTCall -Endpoint cluster/me -Method GET #gets the id of the current rubrik cluster
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Connection to $($Rubrik.RubrikDevice) successful."
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Storing the Rubrik ID..."
        $Rubrik.ID = $RubrikClusterID.id
        Disconnect-Rubrik -Confirm:$false
    }
    catch
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Connection to $($Rubrik.RubrikDevice) failed!!! Error encountered is:`n`r$($Error[0])`n`rScript exiting!!!"
        exit
    }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying cluster $($Rubrik.Cluster)..."
    try
    {
        Get-Cluster $($Rubrik.Cluster) -ErrorAction SilentlyContinue | Out-Null
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Cluster $($Rubrik.Cluster) is valid."
    }
    catch
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Cluster $($Rubrik.Cluster) is invalid!!! Script exiting!!!"
        exit
    }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying host $($Rubrik.Host)..."
    try
    {
        Get-VMHost $($Rubrik.Host) -ErrorAction SilentlyContinue | Out-Null
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Host $($Rubrik.Host) is valid."
    }
    catch
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Host $($Rubrik.Host) is invalid!!! Script exiting!!!"
        exit
    }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying datastore $($Rubrik.Datastore)..."
    try
    {
        Get-Datastore $($Rubrik.Datastore) -ErrorAction SilentlyContinue | Out-Null
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Datastore $($Rubrik.Datastore) is valid"
    }
    catch
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Datastore $($Rubrik.Datastore) is invalid!!! Script exiting!!!"
        exit
    }

    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying 'Templates' folder..."
    try
    {
        Get-Datacenter $($Rubrik.Datacenter) | Get-Folder "Templates" | Out-Null
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Templates folder located."
    }
    catch
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Templates folder not found in $($Rubrik.Datacenter) Datacenter!!! Script exiting!!!"
        exit
    }
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking connection to IAD Rubrik..."
try
{
    Connect-Rubrik IAD-RUBK001 -Credential $RubrikCred | Out-Null
    $RubrikClusterID = Invoke-RubrikRESTCall -Endpoint cluster/me -Method GET #gets the id of the current rubrik cluster
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Connection to IAD Rubrik successful."
}
catch
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "Connection to IAD Rubrik cluster failed!!! Script exiting"
    exit
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking to make sure all enabled Rubriks have an SLA with the correct replication target..."
foreach ($Rubrik in $Rubriks)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying SLA for $($Rubrik.RubrikDevice)..."
    $SLA = Get-RubrikSLA | Where-Object { $_.Name -eq "Gold Templates to $($Rubrik.RubrikDevice)" }
    if ($null -eq $SLA)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "IAD Rubrik does not have an SLA for $($Rubrik.RubrikDevice)!!! Script exiting!!!"
        exit
    }
    else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "SLA for $($Rubrik.RubrikDevice) found." }
    
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Verifying replication target..."
    if ($SLA.replicationSpecs.locationId -ne $Rubrik.ID)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString "SLA replication target is incorrect!!! Script exiting!!!"
        exit
    }
    else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "SLA replicaiton target verified." }
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Environment and sanity checks completed successfully. Starting the replication process which could take several hours."
Read-Host "Press 'Enter' to continue..."

##################
#End: Environment and sanity checks
##################

#Inform IEC and DevOps that template replication is starting.
$EmailBody = "All,`n`nPlease be advised that the template replication process has been started in the IAD vCenter. This means that templates beginning with 'TPL_' will be deleted and recreated. The process will not interrupt the creation of a VM (the delete command will wait until the template is not being used) but may prevent you from starting a VM creation request. Note that some sites might not get updated templates due to [reasons].`n`nAdditional emails will follow to provide progress updates.`n`nAny questions, comments, or concerns should be directed to Nik Whittington or Chris Dupree.`n`nThank you!!!"
Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Started!!!" -Priority High -body $EmailBody

$Snapshots = @()

#Kick off template backups
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating manual backup jobs for each SLA..."
foreach ($Rubrik in $Rubriks)
{
    foreach ($TemplateName in $TemplateNames)
    {
        $Snapshots += New-Object -Type PSObject -Property (@{
            id = $(Get-RubrikVM -name $TemplateName | Where-Object { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | New-RubrikSnapshot -SLA "Gold Templates to $($Rubrik.RubrikDevice)" -Confirm:$false).id
            Rubrik = $($Rubrik.RubrikDevice)
            Template = $TemplateName
            BackupComplete = "Not Complete"})
    }
}

#Wait for all backups to complete
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for manual backup jobs to complete..."
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
        Write-Host "$($Snapshot.Rubrik) - $($Snapshot.Template) --> $($Snapshot.BackupComplete)"
    }
    Start-Sleep 30
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Backup jobs complete."

if ($($IADInfo.Enable) -eq "yes")
{
    #Create templates at IAD-Prod from the GOLD VMs
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Creating templates in IAD-PROD..."
    foreach ($TemplateName in $TemplateNames)
    {
        $TplName = $TemplateName.replace("GOLD","IAD-PROD")
        if ($null -ne (Get-Template $TplName -ErrorAction SilentlyContinue))
        {
            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Deleting $TplName..."
            Remove-Template $TplName -DeletePermanently -Confirm:$false | Out-Null
        }
        New-VM -VM $TemplateName -Datastore $(Get-Datastore $($IADInfo.Datastore)) -DiskStorageFormat Thick -Name $TplName -VMHost $($IADInfo.Host) | Out-Null
        Set-VM $TplName -ToTemplate -Confirm:$false | Out-Null
        Move-Template -Template $TplName -Destination $(Get-Datacenter $($IADInfo.Datacenter) | Get-Folder "Templates")
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "$TplName has been recreated and is ready for use."
        Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Update..." -body "$TplName has been recreated and is ready for use."
    }
}
else { DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Skipping IAD template creation..." }

#Gather all snapshot endpoints
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Obtaining a list of snapshot endpoints..."
$Endpoints = @()
foreach ($Snapshot in $Snapshots)
{
    $Endpoints += New-Object -Type PSObject -Property (@{
        id = ($(Invoke-RubrikRESTCall -Endpoint "vmware/vm/request/$($Snapshot.id)" -Method Get).links | Where-Object { $_.rel -eq "result" }).href.replace("https://iad-rubk001/api/v1/vmware/vm/snapshot/","")
        Rubrik = $Snapshot.Rubrik
        Template = $Snapshot.Template
        ReplicationComplete = "Not Complete"})
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Exporting Snapshot information to file..."
$Endpoints | Select-Object Rubrik, Template, @{Name="Endpoint ID";Expression={$_.id}} | Out-File .\~Logs\"$ScriptName $ScriptStarted.debug" -append

#Monitor for replication completion
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for replication to complete..."
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
        Write-Host "$($Endpoint.Rubrik) - $($Endpoint.Template) --> $($Endpoint.ReplicationComplete)"
    }
    Start-Sleep 60
}

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Disconnecting from IAD Rubrik..."
Disconnect-Rubrik -Confirm:$false

#Export new VMs to convert to templates
foreach ($Rubrik in $Rubriks)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Connecting to $($Rubrik.RubrikDevice)..."
    Connect-Rubrik $($Rubrik.RubrikDevice) -Credential $RubrikCred | Out-Null

    foreach ($TemplateName in $TemplateNames)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Issuing export task on $($Rubrik.RubrikDevice) for $TemplateName..."
        $Replica = Get-RubrikVM $TemplateName | Where-Object { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | Get-RubrikSnapshot | Select-Object -First 1 #gets the ID of the replicated snapshot using the rubrik cluster ID
        $ExportHost = $(Invoke-RubrikRESTCall -Endpoint vmware/host -Method Get).data | Where-Object { $_.name -eq "$($Rubrik.Host)" -and $_.primaryClusterId -eq "$($Rubrik.ID)" } #gets the Rubrik ID of the host listed in the data file using the rubrik cluster ID
        $ExportDatastore = $ExportHost.datastores | Where-Object { $_.name -eq $($Rubrik.Datastore) } #gets the Rubrik ID of the datastore listed in the data file from the exporthost info above
        $body = New-Object -TypeName PSObject -Property @{'hostId'=$($Exporthost.id);'datastoreId'=$($ExportDatastore.id)} #Assemble the POST payload for the REST API call
        Invoke-RubrikRESTCall -Endpoint vmware/vm/snapshot/$($Replica.id)/export -Method POST -Body $body | Out-Null #make rest api call to create an export job
    }

    Disconnect-Rubrik -Confirm:$false
}

#Wait for exports to complete, power down, rename and convert to templates.
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Starting export completion checks. Once a VM export is complete, the VM will be powered down, renamed and converted to template..."
while ($true)
{
    $Complete = $true
    foreach ($Rubrik in $Rubriks)
    {
        $LocalGoldCopies = Get-Cluster $($Rubrik.Cluster) | Get-VM TPL_GOLD*
        foreach ($LocalGoldCopy in $LocalGoldCopies)
        {
            $PowerState = $LocalGoldCopy.PowerState
            if ($PowerState -eq "PoweredOn") 
            {
                foreach($TemplateName in $TemplateNames)
                {
                    if ($LocalGoldCopy.Name -like "$TemplateName*") 
                    {
                        $TemplateNameModified = $TemplateName.Replace("GOLD", $($Rubrik.Cluster))

                        if ($null -ne (Get-Template $TemplateNameModified -ErrorAction SilentlyContinue))
                        {
                            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Deleting $TemplateNameModified..."
                            Remove-Template $TemplateNameModified -DeletePermanently -Confirm:$false
                        }

                        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Converting '$($LocalGoldCopy.Name)' at '$($Rubrik.Cluster)' to template..."
                        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Waiting for VMware tools to start..."
                        $Ready = $false
                        while (!($Ready))
                        {
                            $ToolsStatus = (Get-VM -Name $($LocalGoldCopy.Name)).Guest.ExtensionData.ToolsStatus
                            if ($ToolsStatus -eq "toolsOK" -or $ToolsStatus -eq "toolsOld") { $Ready = $true }
                            Start-Sleep 5
                        }
                        Clear-Variable ToolsStatus
                        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Shutting down the VM..."
                        Shutdown-VMGuest $($LocalGoldCopy.Name) -Confirm:$false | Out-Null
                        while ($PowerState -eq "PoweredOn")
                        {
                            Start-Sleep 5
                            $PowerState = (Get-VM $($LocalGoldCopy.Name)).PowerState
                        }
                        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Renaming VM..."
                        $VMRenamed = Get-Cluster $($Rubrik.Cluster) | Get-VM $($LocalGoldCopy.Name) | Set-VM -Name $TemplateNameModified -Confirm:$false
                        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Converting to template..."
                        $VMConverted = Set-VM $VMRenamed -ToTemplate -Confirm:$false
                        Move-Template -Template $VMConverted -Destination $(Get-Datacenter $($Rubrik.Datacenter) | Get-Folder "Templates")
                        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Continuing export completion checks..."
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

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Template replication has completed successfully!!!"
$EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Completed!!!" -body $EmailBody
