#[CmdletBinding()]
#Param(
#    [Parameter()] [string] $InputFile,
#    [Parameter()] $DomainCredentials = $null,
#    [Parameter()] $SendEmail = $true
#)
#
#Import-Module Rubrik
#
#Connect-Rubrik IAD-RUBK001

#Get a list of all Template backup SLA's and create empty array for snapshot request data
$SLAs = Get-RubrikSLA | where { $_.Name -like "Gold Templates*" }
$Snapshots = @()

#Kick off template backups
foreach ($SLA in $SLAs)
{
    $Snapshots += Get-RubrikVM -name TPL_GOLD_2K12R2 | ? {$_.guestCredentialAuthorizationStatus -eq "SUCCESSFUL" } | New-RubrikSnapshot -SLA $($SLA.name) -Confirm:$false
}

#Wait for all backups to complete
while($true)
{
    $Complete = $true
    foreach ($Snapshot in $Snapshots)
    {
        $Status = Invoke-RubrikRESTCall -Endpoint "vmware/vm/request/$($Snapshot.id)" -Method Get
        if ($Status.Status -ne "SUCCEEDED") { $Complete = $false }
        Write-Host "Waiting for snapshot completion..."
        Start-Sleep 30
    }

    if ($Complete) { Write-Host "Snapshots complete."; break }
}

#Gather all snapshot endpoints
$Endpoints = @()
foreach ($Snapshot in $Snapshots)
{
    $Endpoints += Invoke-RubrikRESTCall -Endpoint "vmware/vm/request/$($Snapshot.id)" -Method Get
}

#Monitor for replication completion
while($true)
{
    $Complete = $true
    foreach ($Endpoint in $Endpoints)
    {
        $EndpointID = $($EndPoint.links | where { $_.rel -eq "result" }).href.replace("https://iad-rubk001/api/v1/vmware/vm/snapshot/","")

        Invoke-RubrikRESTCall -Endpoint "vmware/vm/snapshot/$EndpointID" -Method Get | Select-Object replicationLocationIds
    }

    Start-Sleep 60
}