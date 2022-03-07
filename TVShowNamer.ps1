[CmdletBinding()]
param (
    [Parameter()] [ValidateSet("TV1","TV2","Cartoon")] $ShowType,
    [Parameter()] $ShowName,
    [Parameter()] $Season
)

# $Season = "1"
# $ShowName = "Shadowhunters"
if ($ShowType -eq "TV1") { $Path = "\\storage1\Media\TV Shows\$ShowName\Season $Season" }
if ($ShowType -eq "TV2") { $Path = "\\storage2\Media\TV Shows\$ShowName\Season $Season" }
if ($ShowType -eq "Cartoon") { $Path = "\\storage1\Media\Cartoons\$ShowName\Season $Season" }

$i = 1

$Files = gci $Path | sort Name

foreach ($File in $Files)
{
    $Extension = (Get-Item -LiteralPath $Path\$File).Extension
    $NewName = $ShowName + " - " + "s" + $Season + "e" + $i + $Extension
    Rename-Item -LiteralPath $File.FullName -NewName $NewName
    $i += 1
}