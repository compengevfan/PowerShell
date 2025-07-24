[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [string] $csvfile,
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
    Invoke-RestMethod -Method $Method -Uri "$PlexURL$Endpoint" -Headers $headers
}

#Get data from the csv file
Write-Host "Reading playlist from $csvfile"
$Playlist = Import-Csv $csvfile
$PlaylistName = (Split-Path $csvfile -Leaf).Split(".")[0]

#Get all the music from plex
Write-Host "Fetching music library from Plex server $PlexServer"
$MusicLibrary = Invoke-PlexRequest -Method "Get" -Endpoint "/library/sections/4/all?type=10"

#Find all the ratingKeys for the files
Write-Host "Matching tracks from playlist to Plex library"
$Tracks = @()
foreach ($Entry in $Playlist) {
    # Filter and extract ratingKeys
    $matchingKeys = $MusicLibrary.MediaContainer.Metadata | Where-Object { $_.grandparentTitle -eq $Entry.artist -and $_.title -eq $Entry.song -and $_.parentTitle -eq $Entry.album } | Select-Object -ExpandProperty ratingKey

    if ($matchingKeys.count -eq 0) { Write-Host "No match found for artist '$($Entry.artist)' and song '$($Entry.song)' on '$($Entry.album)'" -ForegroundColor Red }
    if ($matchingKeys.count -gt 1) { Write-Host "Found $($matchingKeys.count) matches for artist '$($Entry.artist)' and song '$($Entry.song)'" -ForegroundColor Yellow }
    if ($matchingKeys.count -eq 1) { 
        Write-Verbose "ratingKey $matchingKeys;artist '$($Entry.artist)';song '$($Entry.song)'"
        $Tracks += $matchingKeys
    }
}

write-host "ratingKeys found: $($Tracks.Count)"
# Write-Debug "List of ratingKeys found: $Tracks"

#Confirm before proceeding
$Proceed = Read-Host "Proceed with creating playlist? (y/n)"
if ($Proceed -ne 'y') {
    Write-Host "Aborting playlist creation."
    return
}

#Get the Machine ID
Write-Host "Fetching Machine ID from Plex server"
$Response = Invoke-PlexRequest -Method "Get" -Endpoint "/identity"
$MachineID = $Response.MediaContainer.MachineIdentifier

#Create the playlist
Write-Host "Creating playlist '$PlaylistName' on Plex server"
$Response = Invoke-PlexRequest -Method "Post" -Endpoint "/playlists?type=audio&title=$PlaylistName&smart=0&uri=server://$MachineID/com.plexapp.plugins.library"
$PlaylistKey = $Response.MediaContainer.Playlist.ratingKey

#Add the tracks to the playlist
Write-Host "Adding tracks to playlist '$PlaylistName'"
foreach ($Track in $Tracks) {
    $Response = Invoke-PlexRequest -Method "Put" -Endpoint "/playlists/$PlaylistKey/items?uri=server://$MachineID/com.plexapp.plugins.library/library/metadata/$Track"
    Write-Verbose "Response for adding ratingKey $Track is: $($Response.OuterXml)"
}
