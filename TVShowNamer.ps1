[CmdletBinding()]
param (
    [Parameter()] [ValidateSet("TV1","TV2","Cartoon")] $ShowType,
    [Parameter()] $ShowName,
    [Parameter()] $Season
)
#Requires -Version 7.2

if ($ShowType -eq "TV1") { $Path = "\\storage1\Media\TV Shows\$ShowName\Season $Season" }
if ($ShowType -eq "TV2") { $Path = "\\storage2\Media\TV Shows\$ShowName\Season $Season" }
if ($ShowType -eq "Cartoon") { $Path = "\\storage1\Media\Cartoons\$ShowName\Season $Season" }

$i = 1

$ToNatural = { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) }

$Files = Get-ChildItem $Path | Sort-Object $ToNatural

foreach ($File in $Files)
{
    $Extension = (Get-Item -LiteralPath $File).Extension
    $NewName = $ShowName + " - " + "s" + $Season + "e" + $i + $Extension
    Rename-Item -LiteralPath $File.FullName -NewName $NewName
    $i += 1
}