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
$Playlist = Import-Csv "C:\Cloud\Dropbox\Music Playlists\$csvfile"
$PlaylistName = (Split-Path $csvfile -Leaf).Split(".")[0]

#Get all the music from plex
Write-Host "Fetching music library from Plex server $PlexServer"
$MusicLibrary = Invoke-PlexRequest -Method "Get" -Endpoint "/library/sections/4/all?type=10"
$LibraryTracks = @($MusicLibrary.MediaContainer.Metadata)

#Find all the ratingKeys for the files
Write-Host "Matching tracks from playlist to Plex library"
$Tracks = @()
$Unmatched = @()
$Ambiguous = @()
$ResolvedByTrackNo = 0
foreach ($Entry in $Playlist) {
    # Match on artist/album/song first. TrackNo is an OPTIONAL tie-breaker: it is only
    # consulted when that match comes back ambiguous. Doing it this way means a CSV
    # with no TrackNo column (or a row that leaves it blank) still works, and a TrackNo
    # that disagrees with Plex's index can no longer silently zero out a good match.
    $Candidates = @($LibraryTracks | Where-Object { $_.grandparentTitle -eq $Entry.artist -and $_.title -eq $Entry.song -and $_.parentTitle -eq $Entry.album })

    if ($Candidates.Count -eq 0) {
        Write-Host "No match found for artist '$($Entry.artist)' and song '$($Entry.song)' on '$($Entry.album)'" -ForegroundColor Red
        $Unmatched += $Entry
        continue
    }

    if ($Candidates.Count -eq 1) {
        Write-Verbose "ratingKey $($Candidates[0].ratingKey);artist '$($Entry.artist)';song '$($Entry.song)'"
        $Tracks += $Candidates[0].ratingKey
        continue
    }

    #More than one hit - try to resolve it with TrackNo
    $Indexes = ($Candidates | ForEach-Object { $_.index }) -join ', '
    if ([string]::IsNullOrWhiteSpace($Entry.TrackNo)) {
        Write-Host "Found $($Candidates.Count) matches for artist '$($Entry.artist)' and song '$($Entry.song)' on '$($Entry.album)' and no TrackNo to choose between them (track numbers in Plex: $Indexes). Skipping." -ForegroundColor Yellow
        $Ambiguous += $Entry
        continue
    }

    $ByTrackNo = @($Candidates | Where-Object { $_.index -eq $Entry.TrackNo })
    if ($ByTrackNo.Count -eq 1) {
        Write-Host "Found $($Candidates.Count) matches for '$($Entry.song)' - TrackNo $($Entry.TrackNo) selected ratingKey $($ByTrackNo[0].ratingKey)" -ForegroundColor DarkGray
        Write-Verbose "ratingKey $($ByTrackNo[0].ratingKey);artist '$($Entry.artist)';song '$($Entry.song)';TrackNo $($Entry.TrackNo)"
        $Tracks += $ByTrackNo[0].ratingKey
        $ResolvedByTrackNo++
        continue
    }

    if ($ByTrackNo.Count -eq 0) {
        Write-Host "Found $($Candidates.Count) matches for artist '$($Entry.artist)' and song '$($Entry.song)', but none is TrackNo $($Entry.TrackNo) (track numbers in Plex: $Indexes). Skipping." -ForegroundColor Yellow
    }
    else {
        Write-Host "Found $($Candidates.Count) matches for artist '$($Entry.artist)' and song '$($Entry.song)'; TrackNo $($Entry.TrackNo) still matches $($ByTrackNo.Count) of them. Skipping." -ForegroundColor Yellow
    }
    $Ambiguous += $Entry
}

write-host "ratingKeys found: $($Tracks.Count)"
if ($ResolvedByTrackNo -gt 0) { Write-Host "  ($ResolvedByTrackNo of those were ambiguous and resolved by TrackNo)" -ForegroundColor DarkGray }
if ($Unmatched.Count -gt 0) { Write-Host "  $($Unmatched.Count) not found" -ForegroundColor DarkGray }
if ($Ambiguous.Count -gt 0) { Write-Host "  $($Ambiguous.Count) skipped as ambiguous - add a TrackNo for these rows to include them" -ForegroundColor DarkGray }
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
