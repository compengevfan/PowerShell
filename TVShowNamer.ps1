[CmdletBinding()]
param (
    [Parameter()] $ShowName,
    [Parameter()] $Season
)

# $Season = "1"
# $ShowName = "Shadowhunters"
$Path = "\\storage2\Media\TV Shows\$ShowName\Season $Season"

$i = 1

$Files = gci $Path | sort Name

foreach ($File in $Files)
{
    $NewName = $ShowName + " - " + "s" + $Season + "e" + $i + ".mkv"
    Rename-Item $File.FullName -NewName $NewName
    $i += 1
}