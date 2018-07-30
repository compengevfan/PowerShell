[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [string] $SeriesName,
    [Parameter(Mandatory=$true)] [int] $SeasonNumber,
    [Parameter(Mandatory=$true)] [string] $SeasonPath
)

$BeginCommand = '"c:\Program Files\Handbrake\HandBrakeCLI" -Z "Roku 720p30 Surround" --no-dvdnav -i'
$EndCommand = '.mp4" -m -a "1" -s "scan"'

$BatchFileOutput = ""

$EpisodeNumber = 1

$Path = "FileSystem::" + $SeasonPath
$Disks = gci $Path

foreach ($Disk in $Disks)
{
    Write-Host "Processing disk: $($Disk.FullName)"
    [int]$EpisodeCount = Read-Host "How many episodes on this disk?"

    while($EpisodeCount -ne 0)
    {
        $Title = Read-Host "Title number for episode $EpisodeNumber"

        $InputLocation = '"' + $($Disk.FullName) + '" -t'

        $OutputLocation = '-o "\\STORAGE1\Media\TV Shows\' + "$SeriesName\Season $SeasonNumber\$SeriesName - s$SeasonNumber" + "e$EpisodeNumber"

        $BatchFileOutput += "$BeginCommand $InputLocation $Title $OutputLocation$EndCommand`r`n"

        $EpisodeNumber++
        $EpisodeCount--
    }
    Write-Host "Going to next disk..."
}

if (!(Test-Path $("G:\Cloud\Dropbox\EpisodeTracker" + "\$SeriesName"))) { New-Item "$("G:\Cloud\Dropbox\EpisodeTracker" + "\$SeriesName")" -ItemType directory }
$BatchFileOutput | Out-File $("G:\Cloud\Dropbox\EpisodeTracker" + "\$SeriesName\" + "Season $SeasonNumber" + ".bat") -Encoding ascii