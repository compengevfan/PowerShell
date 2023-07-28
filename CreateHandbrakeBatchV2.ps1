[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [string] $ShowPath,
    [Parameter(Mandatory=$true)] [int] $SeasonNumber
)

#requires -Version 3.0

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }

$BeginCommand = '"c:\Program Files\Handbrake\HandBrakeCLI" --preset-import-file "C:\HBPresets\Test265.json" -Z "Test265" --no-dvdnav -i'
$EndCommand = '.mkv" -m -a "1" -s "scan"'

Set-Location "G:\Cloud\Dropbox\EpisodeTracker"
$SeasonFile = Get-DfFileName -Filter "csv"
Set-Location $ScriptPath
$SeasonFileObject = Get-Item $SeasonFile
$SeasonInfo = Import-Csv $SeasonFile
$SeriesName = $SeasonFileObject.Directory.Name

$BatchFileOutput = ""

$Path = "FileSystem::" + $ShowPath + "\Season " + $SeasonNumber
$Disks = Get-ChildItem $Path

$DiskCounter = 1

foreach ($Disk in $Disks)
{
    Invoke-DfLogging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Processing disk: $($Disk.FullName)"

    $Episodes = $SeasonInfo | Where-Object { $_.Disk -eq $DiskCounter }

    foreach ($Episode in $Episodes)
    {
        $InputLocation = '"' + $($Disk.FullName) + '" -t'
        $OutputLocation = '-o "\\STORAGE2\Media\TV Shows\' + "$SeriesName\Season $SeasonNumber\$SeriesName - s$SeasonNumber" + "e$($Episode.Episode)"
        $BatchFileOutput += "$BeginCommand $InputLocation $($Episode.Title) $OutputLocation$EndCommand`r`n"
    }

    $DiskCounter++
}

$BatchFileOutput | Out-File $($SeasonFileObject.DirectoryName + "\Season $SeasonNumber" + ".bat") -Encoding ascii

if (!(Test-Path "\\STORAGE2\Media\TV Shows\$SeriesName\Season $SeasonNumber\")) { New-Item "\\STORAGE2\Media\TV Shows\$SeriesName\Season $SeasonNumber\" -ItemType Directory } 

#Start-Process -FilePath $($SeasonFileObject.DirectoryName + "\Season $SeasonNumber" + ".bat")