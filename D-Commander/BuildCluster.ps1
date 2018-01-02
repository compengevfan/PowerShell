[CmdletBinding()]
Param(
    [Parameter()] [string] $InputFile,
    [Parameter()] $SendEmail = $true
)

##################
#System Variables
##################
#$ErrorActionPreference = "SilentlyContinue"

Function Get-FileName
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $initialDirectory = Get-Location
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "JSON (*.json)| *.json"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

if ($InputFile -eq "" -or $InputFile -eq $null) { cls; Write-Host "Please select a JSON file..."; $InputFile = Get-FileName }

$InputFileName = Get-Item $InputFile | % {$_.BaseName}
$ScriptStarted = Get-Date -Format MM-dd-yyyy_hh-mm-ss

##################
#Email Variables
###################emailTo is a comma separated list of strings eg. "email1","email2"
$emailFrom = "ClusterConfig@fanatics.com"
$emailTo = "cdupree@fanatics.com"
$emailServer = "smtp.ff.p10"

##################
#Functions
##################
if (!(Test-Path .\Logs)) { New-Item -Name "Logs" -ItemType Directory | Out-Null }

Function DoLogging
{
    Param(
        [Parameter(Mandatory=$true)][ValidateSet("Succ","Info","Warn","Err")] [string] $LogType,
        [Parameter()] [string] $LogString
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$TimeStamp $LogString" | Out-File .\Logs\"$InputFileName $ScriptStarted.log" -append

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
            $EmailBody = Get-Content .\Logs\$InputFileName + " " + $ScriptStarted + ".log" | Out-String
            if ($SendEmail) { Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "ClusterConfig Encountered an Error" -body $EmailBody }
        }
    }
}

