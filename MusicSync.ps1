[CmdletBinding()]
Param(
    [string] $MusicSource = "G:\Music",
    [string] $MusicDestination = "G:\Cloud\Dropbox\Music Root\Music",
    [string] $PlaylistDestination = "G:\Cloud\Dropbox\Music Root\Playlists",
    [string] $AndroidPath = "/storage/804C-0805/Music Root/"
)

#Run Robocopy to mirror destination with source
if ($PlaylistOnly -ne "Yes")
{
	robocopy $MusicSource $MusicDestination /mir /COPY:DT /XD "Automatically Add to iTunes" /XF ".iTunes Preferences.plist", ".DS_Store" /XO #/log:".\MusicSyncV3RobocopyLog.txt"
}

#Create a copy of the iTunes LIbrary file
if ((Test-Path ".\iTunes Music Library.xml"))
{
    Remove-Item ".\iTunes Music Library.xml"
}

#Remove Playlists
$OldPlaylists = gci $PlaylistDestination
if ($OldPlaylists -ne $null)
{
    Remove-Item –path $PlaylistDestination -Recurse -Include *.m3u
}

#Make a copy of the iTunes Library file
Write-Host ("Making a copy of the iTunes Library...")
Copy-Item "C:\Users\cdupree\Music\iTunes\iTunes Music Library.xml" .\

#Import Library
Write-Host ("Reading library file...")
[xml]$Library = Get-Content ".\iTunes Music Library.xml"

#Get Track List
Write-Host("Exporting track list...")
$TracksXML = $Library.plist.dict.dict.dict
$TracksArray = @()
foreach ($TrackXML in $TracksXML)
{
	$TracksArray += New-Object -Type PSObject -Property (@{
        ID = $($TrackXML.integer[0])
        TimeIn_ms = $($TrackXML.integer[2].ToString())
        Title = $($TrackXML.string[2])
        Artist = $($TrackXML.string[3])
        Location = $($TrackXML.string[(($TrackXML.string.Count) - 1)])
        })
}

#Get My Playlists
Write-Host("Exporting playlists...")
$MyPlaylists = $Library.plist.dict.array.dict | ? {$_.key[3] -eq "Name" -and $_.key[4] -eq "Playlist Items"}

$PlaylistCount = 1

#Get Playlist Songs and Build M3U
Write-Host("Processing playlists...")
foreach ($Playlist in $MyPlaylists)
{
	Write-Progress -id 1 -Activity "Processing Playlists" -status "Processing $($Playlist.string[1])" -percentComplete ($PlaylistCount / $($MyPlaylists.Count)*100)

    $M3UText = "#EXTM3U`n"

    $SongCount = 1

    foreach ($Song in $Playlist.array.dict)
    {
        Write-Progress -id 2 -parentid 1 -Activity "Processing Songs" -status "Song $SongCount of $($Playlist.array.dict.Count)" -percentComplete ($SongCount / $($Playlist.array.dict.Count)*100)
        
        #Find Track based on Track ID
		Write-Verbose("Locating Track...")
        $Track = $TracksArray | ? {$_.ID -eq ($Song.integer)}
		Write-Verbose("Track Located...$($Track.Title)")
        $TrackTimeIn_s = $Track.TimeIn_ms.Substring(0,$Track.TimeIn_ms.Length-3)
        $Track.Location = $Track.Location.Replace("file://localhost/G:/", $AndroidPath)
        $Track.Location = $Track.Location.Replace("%E2%80%99", "'")
        $Track.Location = $Track.Location.Replace("%20", " ")

        $M3UText += "#EXTINF:$TrackTimeIn_s,$($Track.Title) - $($Track.Artist)`n"
        $M3UText += "$($Track.Location)`n"

        $SongCount++
    }

    $M3UText | Out-File $PlaylistDestination\$($Playlist.string[1]).m3u
    $PlaylistCount++
}

Write-Host("Script execution complete.")

#M3UFileFormat
##EXTM3U
##EXTINF:[Time in Seconds (In xml file there is a "total time" field in milliseconds]),[Song Title] - [Artist]
#/storage/extSdCard/Android/data/Music/Amaranthe/Amaranthe/01. Leave Everything Behind.m4a