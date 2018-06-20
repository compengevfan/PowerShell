[CmdletBinding()]
Param(
    [Parameter()] [string] $vCenter
)
 
$ScriptPath = $PSScriptRoot
cd $ScriptPath
 
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss
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
 
Check-PowerCLI
Connect-vCenter $vCenter

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "VirtualComplianceCheck@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

##################
#Global Variables
##################
$ESXBuildNumber = "7388607"

#Obtain information
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Retrieving clusters (Excluding 'voice')..."
$ESXClusters = Get-Cluster | ? { $_.Name -notlike "*voice*" } | sort Name
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Retrieving hosts..."
$ESXHosts = Get-VMHost | ? { $_.ConnectionState -eq "Connected" } | sort Name
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Retrieving distributed switches..."
$ESXvDS = Get-VDSwitch | sort Name

DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Importing data file..."
$DataFromFile = Import-Csv .\VirtualComplianceCheck-Data.csv

###############
# Cluster Level Checks excluding "voice" clusters
###############
$clusterfails = @()
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking cluster configurations..."
foreach ($ESXCluster in $ESXClusters)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing $($ESXCluster.Name)..."
    if ($ESXCluster.HAEnabled -eq $false `
     -or $ESXCluster.ExtensionData.Configuration.DasConfig.HostMonitoring -eq "disabled" `
     -or $ESXCluster.ExtensionData.Configuration.DasConfig.DefaultVmSettings.RestartPriority -eq "disabled" `
     -or $ESXCluster.ExtensionData.Configuration.DasConfig.DefaultVmSettings.IsolationResponse -ne "none" `
     -or $ESXCluster.HAAdmissionControlEnabled -eq $true `
     -or $ESXCluster.DrsEnabled -eq $false `
     -or $ESXCluster.DrsAutomationLevel -ne "FullyAutomated" `
     -or $ESXCluster.ExtensionData.ConfigurationEx.DrsConfig.VmotionRate -ne 5 `
     -or $ESXCluster.EVCMode -eq "")
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "$($ESXCluster.Name) has a config problem."
        $clusterfails += New-Object PSObject -Property @{
            Cluster = $ESXCluster.Name
            "HA Enabled" = $ESXCluster.HAEnabled
            "Host Monitoring" = $ESXCluster.ExtensionData.Configuration.DasConfig.HostMonitoring
            "Host Failure Response" = $ESXCluster.ExtensionData.Configuration.DasConfig.DefaultVmSettings.RestartPriority
            "Isolation Response" = $ESXCluster.ExtensionData.Configuration.DasConfig.DefaultVmSettings.IsolationResponse
            "Admission Control" = $ESXCluster.HAAdmissionControlEnabled
            "DRS Enabled" = $ESXCluster.DrsEnabled
            "DRS Automation Level" = $ESXCluster.DrsAutomationLevel
            "DRS Migration Threshold" = $ESXCluster.ExtensionData.ConfigurationEx.DrsConfig.VmotionRate
            "EVC Mode" = "disabled"
        }
    }
}

if ($clusterfails.Count -gt 0)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing improperly configured clusters and building the email body..."
    $EmailBody = "The following cluster settings are misconfigured and their incorrect configuration settings are listed.`r`n`r`n"

    foreach ($clusterfail in $clusterfails)
    {
        DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Adding $($clusterfail.Cluster) to the email..."
        $EmailBody += "Cluster: $($clusterfail.Cluster)`r`n"

        if ($clusterfail.'HA Enabled' -eq $false) { $EmailBody += "HA Enabled: $($clusterfail.'HA Enabled')`r`n" }
        if ($clusterfail.'Host Monitoring' -eq "disabled") { $EmailBody += "Host Monitoring: $($clusterfail.'Host Monitoring')`r`n" }
        if ($clusterfail.'Host Failure Response' -eq "disabled") { $EmailBody += "Host Failure Response: $($clusterfail.'Host Failure Response')`r`n" }
        if ($clusterfail.'Isolation Response' -ne "none") { $EmailBody += "Isolation Response: $($clusterfail.'Isolation Response')`r`n" }
        if ($clusterfail.'Admission Control' -eq $true) { $EmailBody += "Admission Control: $($clusterfail.'Admission Control')`r`n" }
        if ($clusterfail.'DRS Enabled' -eq $false) { $EmailBody += "DRS Enabled: $($clusterfail.'DRS Enabled')`r`n" }
        if ($clusterfail.'DRS Automation Level' -ne "FullyAutomated") { $EmailBody += "DRS Automation Level: $($clusterfail.'DRS Automation Level')`r`n" }
        if ($clusterfail.'DRS Migration Threshold' -ne 5) { $EmailBody += "DRS Migration Threshold: $($clusterfail.'DRS Migration Threshold')`r`n" }
        if ($clusterfail.'EVC Mode' -eq "disabled") { $EmailBody += "EVC Mode: $($clusterfail.'EVC Mode')`r`n" }

        $EmailBody += "`r`n"
    }
}

#Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "VirtualComplianceCheck found config problems in $vCenter cluster checks" -body $EmailBody

###############
# Host Level Checks
###############
$hostfails = @()
DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Checking cluster configurations..."
foreach ($ESXHost in $ESXHosts)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing $($ESXHost.Name)..."
    
    # Checking Build number
    $OSInfo = Get-View -ViewType HostSystem -Filter @{"Name"=$($ESXHost).Name} -Property Name,Config.Product | foreach {$_.Name, $_.Config.Product}
    
    #Correct domain name for FQDN
    $ParentCluster = $HostToConfig.Parent.Name
    $ProperInfo = $DataFromFile | ? { $_.Cluster -eq $ParentCluster }

    if ($OSInfo.Build -ne $ESXBuildNumber `
     -or $ESXHost.Name -notlike "*$($ProperInfo.Domain)" `
     -or 
    #ESXi build number

    #host name is FQDN.

    #NTP Servers

    #SNMP service

    #Domain, domain look up, DNS Servers and Gateway

    #power management policy

    #alarm actions

    #virtual switch config excluding "voice" clusters

    #VAAI and ALUA Config

}

#Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "VirtualComplianceCheck found config problems in $vCenter host checks" -body $EmailBody

###############
# vDS Level Checks
###############

#mtu set to 1500

#Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "VirtualComplianceCheck found config problems in $vCenter vDS checks" -body $EmailBody