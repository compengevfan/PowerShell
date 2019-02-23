[CmdletBinding()]
Param(
    [parameter(Mandatory=$true)] [ValidateSet("dvd","bluray")] [String] $DiskType,
    [Parameter(Mandatory=$true)] [int] $SeasonNumber,
    [Parameter(Mandatory=$true)] [string] $SeasonPath
)

#requires -Version 3.0

$ScriptPath = $PSScriptRoot
cd $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }

switch ($DiskType) {
    "dvd" 
        {
            $BeginCommand = '"c:\Program Files\Handbrake\HandBrakeCLI" -Z "Roku 720p30 Surround" --no-dvdnav -i'
            $EndCommand = '.mp4" -m -a "1" -s "scan"'
        }
    "bluray"
        {
            $BeginCommand = '"c:\Program Files\Handbrake\HandBrakeCLI" -Z "Roku 1080p30 Surround" --no-dvdnav -i'
            $EndCommand = '.mp4" -m -a "1" -s "scan"'
        }
    Default {}
}

Set-Location "C:\Cloud\Dropbox\EpisodeTracker"
$SeasonFile = Get-FileName -Filter "csv"
$SeasonFileObject = Get-Item $SeasonFile
$SeasonInfo = Import-Csv $SeasonFile
$SeriesName = $SeasonFileObject.Directory.Name

$BatchFileOutput = ""

$Path = "FileSystem::" + $SeasonPath
$Disks = Get-ChildItem $Path

$DiskCounter = 1

foreach ($Disk in $Disks)
{
    DoLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing disk: $($Disk.FullName)"

    $Episodes = $SeasonInfo | Where-Object { $_.Disk -eq $DiskCounter }

    foreach ($Episode in $Episodes)
    {
        $InputLocation = '"' + $($Disk.FullName) + '" -t'
        $OutputLocation = '-o "\\STORAGE1\Media\TV Shows\' + "$SeriesName\Season $SeasonNumber\$SeriesName - s$SeasonNumber" + "e$($Episode.Episode)"
        $BatchFileOutput += "$BeginCommand $InputLocation $($Episode.Title) $OutputLocation$EndCommand`r`n"
    }

    $DiskCounter++
}

$BatchFileOutput | Out-File $($SeasonFileObject.DirectoryName + "\Season $SeasonNumber" + ".bat") -Encoding ascii