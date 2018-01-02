#[CmdletBinding()]
#Param(
#    [Parameter()] [string] $InputFile,
#    [Parameter()] $DomainCredentials = $null,
#    [Parameter()] $SendEmail = $true
#)

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
            if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Cloud-O-Mite Encountered an Error" -body $EmailBody }
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
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }

Check-PowerCLI

if (!(Get-Module -Name Rubrik)) { Import-Module Rubrik }

Connect-VIServer iad-vc001.fanatics.corp

#Connect-Rubrik IAD-RUBK001

#Get a list of all Template backup SLA's and create empty array for snapshot request data
DoLogging -LogType Info -LogString "Obtaining a list of all Gold Template SLAs..."
$SLAs = Get-RubrikSLA | where { $_.Name -like "Gold Templates*" }
$Snapshots = @()

#Kick off template backups
DoLogging -LogType Info -LogString "Creating manual backup jobs for each SLA..."
foreach ($SLA in $SLAs)
{
    $Snapshots += Get-RubrikVM -name TPL_GOLD_2K12R2 | ? {$_.guestCredentialAuthorizationStatus -eq "SUCCESSFUL" } | New-RubrikSnapshot -SLA $($SLA.name) -Confirm:$false
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
        Start-Sleep 30
    }

    if ($Complete) { break }
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

    Start-Sleep 60
}

DoLogging -LogType Succ -LogString "Template replication has completed successfully!!!"
if ($SendEmail) { $EmailBody = Get-Content ".\~Logs\ + "ReplicateTemplatesWithRubrik " + $ScriptStarted + ".txt"" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Template Replication Completed!!!" -body $EmailBody }
