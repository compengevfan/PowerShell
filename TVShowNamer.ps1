$Path = "\\storage2\Media\TV Shows\Through.the.Wormhole.Season.1-6.720P-1080p.BDRip.X265.HEVC\Season 6"
$ShowName = "Through the Wormhole"
$Season = "6"

$i = 1

$Files = gci $Path | sort Name

foreach ($File in $Files)
{
    $NewName = $ShowName + " - " + "s" + $Season + "e" + $i + ".mkv"
    Rename-Item $File.FullName -NewName $NewName
    $i += 1
}