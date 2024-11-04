[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [string] $ShowName,
    [Parameter(Mandatory=$true)] [string] $SourceFolder,
    [Parameter(Mandatory=$true)] [ValidateSet("480", "720")] [string] $ResolutionTarget,
    [Parameter()] [int] $SubStringCount,
    [Parameter()] [switch] $ReuseName
)

#requires -Version 7

$BeginCommand = '"c:\Program Files\Handbrake\HandBrakeCLI" --preset-import-file "C:\Program Files\HandBrake\265-MKV-' + $ResolutionTarget + '.json" -Z "265-MKV-' + $ResolutionTarget + '" --no-dvdnav -i'
$EndCommand = '.mkv" -m -a "1" -s "scan"'

if (!(Test-Path "C:\Cloud\Dropbox\EpisodeTracker\~V3\$ShowName")) { New-Item "C:\Cloud\Dropbox\EpisodeTracker\~V3\$ShowName" -ItemType Directory } 

$Folders = Get-ChildItem "\\storage1\storage\Downloads\$SourceFolder" | Sort-Object Name

$FolderCounter = 1

foreach ($Folder in $Folders)
{
    if ($FolderCounter -lt 10){
        $SeasonNumber = "0" + $FolderCounter
    }
    else {
        $SeasonNumber = $FolderCounter
    }
    
    $BatchFileOutput = ""
    $files = Get-ChildItem $Folder

    foreach ($file in $files)
    {
        if ($ReuseName){
            $OutputFileName = $file.Name.split('.')[0]
        }
        else {
            $OutputFileName = $file.Name.Substring(0,$SubStringCount)
        }
        $InputLocation = '"' + $file + '"'
        $OutputLocation = '-o "\\storage3\Media\TV Shows\' + "$ShowName\Season $SeasonNumber\" + $OutputFileName
        $BatchFileOutput += "$BeginCommand $InputLocation $($Episode.Title) $OutputLocation$EndCommand`r`n"
    }

    $BatchFileOutput | Out-File $("C:\Cloud\Dropbox\EpisodeTracker\~V3\$ShowName\$ShowName - Season $SeasonNumber" + ".bat") -Encoding ascii -Force

    if (!(Test-Path "\\storage3\Media\TV Shows\$ShowName\Season $SeasonNumber")) { New-Item "\\storage3\Media\TV Shows\$ShowName\Season $SeasonNumber" -ItemType Directory } 

    $FolderCounter++
}
