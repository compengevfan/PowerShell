[CmdletBinding()]
Param(
)

$BeginCommand = '"c:\Program Files\Handbrake\HandBrakeCLI" -Z "Normal" --no-dvdnav -i'
$EndCommand = '.mp4" -m -a "1" -s "scan"'

$BatchFileOutput = ""

$EpisodeNumber = 1

$SeriesName = Read-Host "Please provide the name of the TV Series"

$SeasonNumber = Read-Host "Please provide the season number"

$Season = Read-Host "Please provide the path to the season folder"

$Path = "FileSystem::" + $Season
$Disks = gci $Path

foreach ($Disk in $Disks)
{
    $EpisodeCount = Read-Host "How many episodes on this disk?"

    while($EpisodeCount -ne 0)
    {
        $Title = Read-Host "Title number for episode $EpisodeNumber"

        $InputLocation = '"' + $($Disk.FullName) + '" -t'

        $OutputLocation = '-o "\\STORAGE1\Media\TV Shows\' + "$SeriesName\Season $SeasonNumber\$SeriesName - s$SeasonNumber" + "e$EpisodeNumber"

        $BatchFileOutput += "$BeginCommand $InputLocation $Title $OutputLocation$EndCommand"

        $EpisodeNumber++
        $EpisodeCount--
    }
    Write-Host "Going to next disk..."
}

$BatchFileOutput