[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] $CredFile,
    [Parameter(Mandatory=$true)] $GoAnywhereServer
)
 
$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
  

if ($CredFile -ne $null)
{
    Remove-Variable Credential_To_Use -ErrorAction Ignore
    New-Variable -Name Credential_To_Use -Value $(Import-Clixml $($CredFile))
}

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "GoAnywhereMonitor@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

$MaxTime = 30

if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
 }
[ServerCertificateValidationCallback]::Ignore()

if (Test-Path .\GoAnywhereMonitorMDT-Data.txt)
{
    $Cancelled = Get-Content .\GoAnywhereMonitorMDT-Data.txt
    Remove-Item .\GoAnywhereMonitorMDT-Data.txt
}
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Running check as $($Credential_To_Use.Username)"
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting the currently running job list..."
$ActiveJobs = (Invoke-RestMethod -Uri https://jax-mdt001.ff.p10:8001/goanywhere/rest/gacmd/v1/activity/jobs/active -Method Get -Credential $Credential_To_Use).data
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "There are $($ActiveJobs.Count) active jobs."

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Getting the current time for comparison..."
$CurrentTime = Get-Date

foreach ($ActiveJob in $ActiveJobs)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking to see if job number $($ActiveJob.jobNumber) has been running for more than $MaxTime minutes..."
    if ((($CurrentTime - [datetime]"$($ActiveJob.startTime)").TotalMinutes) -gt $MaxTime)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Job number $($ActiveJob.jobNumber) has been running more than $MaxTime minutes..."
        $CurrentJobLog = $(Invoke-RestMethod -Uri https://jax-mdt001.ff.p10:8001/goanywhere/rest/gacmd/v1/jobs/$($ActiveJob.jobNumber) -Method Get -Credential $Credential_To_Use).Trim()
        if ($CurrentJobLog.EndsWith("'createFileList 1.0'"))
        {
            DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Job number $($ActiveJob.jobNumber) appears to be stuck. Checking to see if it was cancelled on the previous run..."
            if ($Cancelled -match $($ActiveJob.jobNumber))
            {
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Warn -LogString "Job number $($ActiveJob.jobNumber) was cancelled on the previous run!!! Sending email for human intervention and exiting script!!!"
                $emailBody = @"
The GoAnywhere cluster that has $GoAnywhereServer in it has at least one job that is stuck. An attempt was made to cancel the job but the attempt failed.

Please login to a member of this cluster and determine which GoAnywhere server owns the stuck job and either restart the GoAnywhere service or the entire server.

Script executed on $($env:computername).
"@
                Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "GoAnywhere Has Stuck Jobs!!!" -body $emailBody
                exit
            }
            else
            {
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Issuing command to cancel job $($ActiveJob.jobNumber)..."
                try { Invoke-RestMethod -Uri https://jax-mdt001.ff.p10:8001/goanywhere/rest/gacmd/v1/jobs/$($ActiveJob.jobNumber)/cancel -Method Post -Credential $Credential_To_Use }
                catch { Write-Host "Gotya" }
                DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Logging job number to ensure cancel was successful on next run..."
                $($ActiveJob.jobNumber) | Out-File .\GoAnywhereMonitorMDT-Data.txt -Append
            }
        }
    }
}
