$Files = gci -recurse Z:\Music | select Extension, attributes | where {($_.attributes -notlike "*Directory*") -and ($_.Extension -notlike "*.m4a*") -and ($_.Extension -notlike "*.mp3*") -and ($_.Extension -notlike "*.m4v*") -and ($_.Extension -notlike "*.avi*") -and ($_.Extension -notlike "*.mp4*")}

$Extensions = @()

foreach ($File in $Files)
{
	$CurrentExt = $File.Extension
	if ($Extensions -notcontains $CurrentExt)
	{
		$Extensions += $CurrentExt
	}
}

$Extensions



$Files = gci -recurse Z:\Music | select FullName, Extension, attributes | where {($_.attributes -notlike "*Directory*") -and ($_.Extension -notlike "*.m4a*") -and ($_.Extension -notlike "*.mp3*") -and ($_.Extension -notlike "*.m4v*") -and ($_.Extension -notlike "*.avi*") -and ($_.Extension -notlike "*.mp4*")}

foreach($File in $Files)
{
	Remove-Item $File.FullName
}

Get-ChildItem C:\Users\cdupree\Music -recurse | Where {$_.PSIsContainer -and @(Get-ChildItem -Lit $_.Fullname -r | Where {!$_.PSIsContainer}).Length -eq 0} | Remove-Item -recurse -whatif