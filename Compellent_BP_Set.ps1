[CmdletBinding()]
Param(
)

#requires -Version 3.0

$ScriptPath = $PSScriptRoot
cd $ScriptPath
<#
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
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
#>
#Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType 
<#
try { $CurrentJobLog = Get-Content "$GoAnywhereLogs\$($CurrentTime.ToString("yyyy-MM-dd"))\$($ActiveJob.jobNumber).log" }
catch 
{
    $String = "Error encountered is:`n`r$($Error[0])`n`rScript executed on $($env:computername)."
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Err -LogString $String
    if ($SendEmail) { Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "$ScriptName Encountered an Error" -Body $String }
    exit
}
#>

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (!($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))
{
    Write-Host "PowerShell session not run as Administrator, which is required to access the registry. Please rerun your command after opening PowerShell as Administrator." -ForegroundColor Red
    exit
}

$MPIOCheck = Get-WmiObject -query "select * from Win32_OptionalFeature where name = 'MultipathIo'"
if ($MPIOCheck.InstallState -eq 1)
{
    Write-Host "MPIO is installed..."
}
else 
{
    Write-Host "MPIO is not installed!!! Please install MPIO and rerun the Compellent BP check manually!!! Script Exiting!!!"
    exit
}

if (Test-Path .\Compellent_BP_Set-Data.csv -ErrorAction SilentlyContinue)
{
    Write-Host "Importing registry problem data file..."
    $DataFromFile = Import-Csv .\Compellent_BP_Set-Data.csv
}
else 
{
    Write-Host "'Compellent_BP_Set-Data.csv' file is missing.`n`rPlease copy this file to the same directory as this script to proceed!!!`n`rScript Exiting!!!"
    exit
}

Write-Host "Getting local server FQDN..."
$ServerName = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

Write-Host "Filtering registry problem data"
$ProblemsToFix = $DataFromFile | Where-Object { $_.Server -eq $ServerName }

foreach ($Problem in $ProblemsToFix)
{
    $FullPath = "HKLM:\$($Problem.Key)"

    $i = $FullPath.Length
    while ($true)
    {
        $i--
        if ($FullPath[$i] -eq "\")
        {
            $Key = $FullPath.Substring(0, $i)
            $Name = $FullPath.Substring($($i)+1,$($FullPath.Length -1) - $i)
            break
        }
    }
    
    if ($($Problem.IncorrectValue) -eq "Value Missing")
    {
        Write-Host "Creating $FullPath..."
        New-ItemProperty -Path $Key -Name $Name -Value $Problem.CorrectValue -PropertyType DWord
    }
    else 
    {
        Write-Host "Updating $FullPath..."
        Set-ItemProperty -Path $Key -Name $Name -Value $Problem.CorrectValue
    }
}

Write-Host "MPIO Registry settings have been updated. Please reboot for changes to take effect." -ForegroundColor Yellow