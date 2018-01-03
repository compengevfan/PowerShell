[CmdletBinding()]
Param(
)

Function DoLogging
{
    Param(
        [Parameter(Mandatory=$true)][ValidateSet("Succ","Info","Warn","Err")] [string] $LogType,
        [Parameter()] [string] $LogString
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$TimeStamp $LogString" | Out-File .\~Logs\"$ScriptName $ScriptStarted.log" -append

    Write-Host -F DarkGray "[" -NoNewLine
    Write-Host -F Green "*" -NoNewLine
    Write-Host -F DarkGray "] " -NoNewLine
    Switch ($LogType)
    {
        Succ { Write-Host -F Green $LogString }
        Info { Write-Host -F White $LogString }
        Warn { Write-Host -F Yellow $LogString }
        Err
        {
            Write-Host -F Red $LogString
            if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Encountered an Error" -body $EmailBody }
        }
    }
}

Function Check-PowerCLI
{
    Param(
    )

    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
        $PrevPath = Get-Location

	    write-host ("Adding PowerCLI...")
        if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts")
        {
            cd "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts"
	        .\Initialize-PowerCLIEnvironment.ps1
        }
        if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts")
        {
            cd "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts"
            .\Initialize-PowerCLIEnvironment.ps1
        }

        cd $PrevPath

	    write-host ("Loaded PowerCLI.")
    }
}

$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "TemplateReplication@fanatics.com"
$emailTo = "cdupree@fanatics.com"#,"devops-engineering@fanatics.com"
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

DoLogging -LogType Info -LogString "Locating all existing templates and targeting for termination..."
$TemplatesGoByeBye = Get-Template TPL_* | Sort-Object name

foreach ($Template in $TemplatesGoByeBye)
{
    DoLogging -LogType Info -LogString "Deleting template '$($Template.Name)...'"
    Remove-Template $Template -DeletePermanently -Confirm:$false
    DoLogging -LogType Succ -LogString "Template '$($Template.Name) deleted...'"
}

DoLogging -LogType Info -LogString "Connecting to IAD Rubrik..."
Connect-Rubrik IAD-RUBK001 -Credential $RubrikCred

#Get a list of all Template backup SLA's and create empty array for snapshot request data
DoLogging -LogType Info -LogString "Obtaining a list of all Gold Template SLAs..."
$SLAs = Get-RubrikSLA | where { $_.Name -like "Gold Templates*" } | Sort-Object Name
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
        if ($Status.replicationLocationId -eq "") { $Complete = $false }
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
    Connect-Rubrik $RemoteRubrik -Credential $RubrikCred
    $RubrikClusterID = Invoke-RubrikRESTCall -Endpoint cluster/me -Method GET #gets the id of the current rubrik cluster
    $Record = $DataFromFile | where { $_.RubrikDevice -eq "$RemoteRubrik" } #gets the proper information for the current Rubrik from the data file

    DoLogging -LogType Info -LogString "Issuing export task on $RemoteRubrik for 2K12R2 template..."
    $Replica = Get-RubrikVM TPL_GOLD_2K12R2 | where { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | Get-RubrikSnapshot | select -First 1 #gets the ID of the replicated snapshot using the rubrik cluster ID
    $ExportHost = $(Invoke-RubrikRESTCall -Endpoint vmware/host -Method Get).data | where { $_.name -eq "$($Record.Host)" -and $_.primaryClusterId -eq "$($RubrikClusterID.id)" } #gets the Rubrik ID of the host listed in the data file using the rubrik cluster ID
    $ExportDatastore = $ExportHost.datastores | where { $_.name -eq $($Record.Datastore) } #gets the Rubrik ID of the datastore listed in the data file from the exporthost info above
    $body = New-Object -TypeName PSObject -Property @{'hostId'=$($Exporthost.id);'datastoreId'=$($ExportDatastore.id)} #Assemble the POST payload for the REST API call
    Invoke-RubrikRESTCall -Endpoint vmware/vm/snapshot/$($Replica.id)/export -Method POST -Body $body #make rest api call to create an export job

    DoLogging -LogType Info -LogString "Issuing export task on $RemoteRubrik for 2K8R2 template..."
    $Replica = Get-RubrikVM TPL_GOLD_2K8R2 | where { $_.primaryClusterId -eq "$($RubrikClusterID.id)" } | Get-RubrikSnapshot | select -First 1 #gets the ID of the replicated snapshot using the rubrik cluster ID
    $ExportHost = $(Invoke-RubrikRESTCall -Endpoint vmware/host -Method Get).data | where { $_.name -eq "$($Record.Host)" -and $_.primaryClusterId -eq "$($RubrikClusterID.id)" } #gets the Rubrik ID of the host listed in the data file using the rubrik cluster ID
    $ExportDatastore = $ExportHost.datastores | where { $_.name -eq $($Record.Datastore) } #gets the Rubrik ID of the datastore listed in the data file from the exporthost info above
    $body = New-Object -TypeName PSObject -Property @{'hostId'=$($Exporthost.id);'datastoreId'=$($ExportDatastore.id)} #Assemble the POST payload for the REST API call
    Invoke-RubrikRESTCall -Endpoint vmware/vm/snapshot/$($Replica.id)/export -Method POST -Body $body #make rest api call to create an export job

    Disconnect-Rubrik -Confirm:$false
}

DoLogging -LogType Succ -LogString "Template replication has completed successfully!!!"
if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Completed!!!" -body $EmailBody }
