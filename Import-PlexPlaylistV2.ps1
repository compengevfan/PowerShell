[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [string] $csvfile,
    [Parameter(Mandatory = $true)] [string] $PlexUrl,
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
    Invoke-RestMethod -Method $Method -Uri "$PlexUrl$Endpoint" -Headers $headers
}

#Get data from the csv file
$Playlist = Import-Csv $csvfile
$PlaylistName = (Split-Path $csvfile -Leaf).Split(".")[0]

#Get all the music from plex
$MusicLibrary = Invoke-PlexRequest -Method "Get" -Endpoint "/library/sections/4/all?type=10"

#Find all the ratingKeys for the files
$Tracks = @()
foreach ($Entry in $Playlist) {
    # Filter and extract ratingKeys
    $matchingKeys = $MusicLibrary.MediaContainer.Metadata | Where-Object { $_.grandparentTitle -eq $Entry.artist -and $_.title -eq $Entry.song } | Select-Object -ExpandProperty ratingKey

    if ($matchingKeys.count -eq 0) { Write-Host "No match found for artist '$($Entry.artist)' and song '$($Entry.song)'" }
    if ($matchingKeys.count -gt 1) { Write-Host "Found $($matchingKeys.count) matches for artist '$($Entry.artist)' and song '$($Entry.song)'" }

    # switch ($matchingKeys.count) {
    #     0 { Write-Host "No match found for artist '$($Entry.artist)' and song '$($Entry.song)'" }
    #     1 { Write-Host "Found 1 match for artist '$($Entry.artist)' and song '$($Entry.song)'" }
    #     default { Write-Host "Found $($matchingKeys.count) matches for artist '$($Entry.artist)' and song '$($Entry.song)'" }
    # }
    
    # $Tracks += $matchingKeys
}

write-host "List of ratingKeys found: "
$Tracks
# #Get the Machine ID
# $Response = Invoke-PlexRequest -Method "Get" -Endpoint "/identity"
# $MachineID = $Response.MediaContainer.MachineIdentifier

# #Create the playlist
# $Response = Invoke-PlexRequest -Method "Post" -Endpoint "/playlists?type=audio&title=$PlaylistName&smart=0&uri=server://$MachineID/com.plexapp.plugins.library"
# $PlaylistKey = $Response.MediaContainer.Playlist.ratingKey

# #Add the tracks to the playlist
# foreach ($Track in $Tracks) {
#     $Response = Invoke-PlexRequest -Method "Put" -Endpoint "/playlists/$PlaylistKey/items?uri=server://$MachineID/com.plexapp.plugins.library/library/metadata/$($Track.ratingKey)"
# }    
