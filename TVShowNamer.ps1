[CmdletBinding()]
param (
    [Parameter()] [ValidateSet("TV1","TV2","Cartoon")] $ShowType,
    [Parameter()] $ShowName,
    [Parameter()] $Season
)

switch ($ShowType) {
    "TV1" { $Path = "\\storage1\Media\TV Shows\$ShowName\Season $Season" }
    "TV2" { $Path = "\\storage2\Media\TV Shows\$ShowName\Season $Season" }
    "Cartoon" { $Path = "\\storage1\Media\Cartoons\$ShowName\Season $Season" }
    Default {}
}

$i = 1

$Files = Get-ChildItem $Path | Sort-Object Name

foreach ($File in $Files)
{
    $Extension = (Get-Item -LiteralPath $Path\$File).Extension
    $NewName = $ShowName + " - " + "s" + $Season + "e" + $i + $Extension
    Rename-Item -LiteralPath $File.FullName -NewName $NewName
    $i += 1
}