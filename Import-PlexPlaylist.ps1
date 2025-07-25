[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [string] $m3ufile,
    [Parameter(Mandatory = $true)] [string] $PlexServer,
    [Parameter(Mandatory = $true)] [string] $PlexToken
)

function Invoke-PlexRequest {
    param (
        [string]$Method,
        [string]$Endpoint
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.add('X-Plex-Token', $PlexToken)
    if ($Method -eq "Get") {
        $headers.Add("Accept", "application/json")
        $headers.Add("Content-Type", "application/json")
    }
    $PlexURL = "http://" + $PlexServer + ":32400"
    Invoke-RestMethod -Method $Method -Uri "$PlexUrl$Endpoint" -Headers $headers
}

#Get data from the m3u file
$Playlist = Get-Content $m3ufile
$PlaylistName = (Split-Path $m3ufile -Leaf).Split(".")[0]

#Get all the music from plex
$MusicLibrary = Invoke-PlexRequest -Method "Get" -Endpoint "/library/sections/4/all?type=10"

#Find all the ratingKeys for the files
$Tracks = @()
foreach ($Song in $Playlist) {
    $FileName = $Song.Split("\")[-1]
    foreach ($Result in $MusicLibrary.MediaContainer.Metadata) {
        foreach ($Media in $Result.Media) {
            foreach ($Part in $Media.Part) {
                # write-host "Part.file is $($Part.file) and FilePath is $Song"
                if ($Part.file -like "*$FileName") {
                    $Tracks += $Result
                }
            }
        }
    }
}

#Get the Machine ID
$Response = Invoke-PlexRequest -Method "Get" -Endpoint "/identity"
$MachineID = $Response.MediaContainer.MachineIdentifier

#Create the playlist
$Response = Invoke-PlexRequest -Method "Post" -Endpoint "/playlists?type=audio&title=$PlaylistName&smart=0&uri=server://$MachineID/com.plexapp.plugins.library"
$PlaylistKey = $Response.MediaContainer.Playlist.ratingKey

#Add the tracks to the playlist
foreach ($Track in $Tracks) {
    $Response = Invoke-PlexRequest -Method "Put" -Endpoint "/playlists/$PlaylistKey/items?uri=server://$MachineID/com.plexapp.plugins.library/library/metadata/$($Track.ratingKey)"
}    
