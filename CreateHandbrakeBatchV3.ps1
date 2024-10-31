[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [string] $ShowName,
    [Parameter(Mandatory=$true)] [string] $SourceFolder,
    [Parameter(Mandatory=$true)] [int] $SubStringCount
)

#requires -Version 7

$BeginCommand = '"c:\Program Files\Handbrake\HandBrakeCLI" --preset-import-file "C:\Program Files\HandBrake\265-MKV-480.json" -Z "265-MKV-480" --no-dvdnav -i'
$EndCommand = '.mkv" -m -a "1" -s "scan"'

if (!(Test-Path "C:\Cloud\Dropbox\EpisodeTracker\~V3\$ShowName")) { New-Item "C:\Cloud\Dropbox\EpisodeTracker\~V3\$ShowName" -ItemType Directory } 

$Folders = Get-ChildItem "\\storage1\storage\Downloads\$SourceFolder" | Sort-Object Name

$FolderCounter = 1

foreach ($Folder in $Folders)
{
    $BatchFileOutput = ""
    $files = Get-ChildItem $Folder

    foreach ($file in $files)
    {
        $InputLocation = '"' + $file + '"'
        $OutputLocation = '-o "\\storage3\Media\TV Shows\' + "$ShowName\Season $FolderCounter\" + "$($file.Name.Substring(0,$SubStringCount))"
        $BatchFileOutput += "$BeginCommand $InputLocation $($Episode.Title) $OutputLocation$EndCommand`r`n"
    }

    $BatchFileOutput | Out-File $("C:\Cloud\Dropbox\EpisodeTracker\~V3\$ShowName\$ShowName - Season $FolderCounter" + ".bat") -Encoding ascii -Force

    if (!(Test-Path "\\storage3\Media\TV Shows\$ShowName\Season $FolderCounter")) { New-Item "\\storage3\Media\TV Shows\$ShowName\Season $FolderCounter" -ItemType Directory } 

    $FolderCounter++
}
