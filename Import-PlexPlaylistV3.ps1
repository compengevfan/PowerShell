<#
.SYNOPSIS
    Creates a Plex audio playlist for a managed (home) user from a CSV track list.

.DESCRIPTION
    V3 of Import-PlexPlaylist. Identical matching logic to V2, but every call is made
    with a managed account's token instead of the server admin token, so the resulting
    playlist is owned by, and visible to, that managed user.

    Only one token is needed: PlexUserToken, the managed account's token. Pass it the
    same way V2 accepted the admin token.

    NOTE: the server cannot tell you which account a token belongs to - the / endpoint
    returns server-level identity (the owner) for every valid token. So this script
    does not try to name the user; it verifies the token by what it can SEE instead,
    and stops if the music library comes back empty.

    CSV columns: Artist, Album, Song are required. TrackNo is optional and is used
    ONLY as a tie-breaker: rows are matched on artist/album/song, and TrackNo is
    consulted just when that match returns more than one hit (the same song appearing
    twice on one album). A row with no TrackNo that matches more than once is skipped
    and reported, with the Plex track numbers listed so a TrackNo can be added.

.EXAMPLE
    .\Import-PlexPlaylistV3.ps1 -csvfile "Road Trip.csv" -PlexServer plex.local `
        -PlexUserToken $KidsToken
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [string] $csvfile,
    [Parameter(Mandatory = $true)] [string] $PlexServer,
    [Parameter(Mandatory = $true)] [string] $PlexUserToken,
    [int] $SectionKey = 4
)

function Invoke-PlexRequest {
    param (
        [string]$Method,
        [string]$Endpoint
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.add('X-Plex-Token', $PlexUserToken)
    if ($Method -eq "Get") {
        $headers.Add("Accept", "application/json")
        $headers.Add("Content-Type", "application/json")
    }
    $PlexURL = "http://" + $PlexServer + ":32400"
    Invoke-RestMethod -Method $Method -Uri "$PlexURL$Endpoint" -Headers $headers
}

#Get data from the csv file
$CsvPath = "C:\Cloud\Dropbox\Music Playlists\$csvfile"
Write-Host "Reading playlist from $CsvPath"
$Playlist = @(Import-Csv $CsvPath)
$PlaylistName = (Split-Path $csvfile -Leaf).Split(".")[0]
Write-Host "CSV rows read   : $($Playlist.Count)"
if ($Playlist.Count -eq 0) { Write-Host "The CSV produced no rows. Nothing to do." -ForegroundColor Red; return }
Write-Host "CSV columns     : $($Playlist[0].PSObject.Properties.Name -join ', ')"

#Get all the music from plex as the supplied account
Write-Host ""
Write-Host "Fetching music library (section $SectionKey) from Plex server $PlexServer"
$MusicLibrary = Invoke-PlexRequest -Method "Get" -Endpoint "/library/sections/$SectionKey/all?type=10"
$LibraryTracks = @($MusicLibrary.MediaContainer.Metadata)
Write-Host "Library tracks visible to this token: $($LibraryTracks.Count)"

if ($LibraryTracks.Count -eq 0) {
    Write-Host "The library came back EMPTY for this token." -ForegroundColor Red
    Write-Host "Either section $SectionKey is not a music library, or it is not shared with this account." -ForegroundColor Red
    Write-Host "Run Test-PlexUserAccess.ps1 with this same token to see which." -ForegroundColor Yellow
    return
}

#Find all the ratingKeys for the files
Write-Host ""
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

#If NOTHING matched, work out why before bailing out
if ($Tracks.Count -eq 0) {
    Write-Host ""
    Write-Host "=== Zero matches against $($LibraryTracks.Count) library tracks - diagnosing ===" -ForegroundColor Cyan
    Write-Host "A sample library track, as this token sees it:" -ForegroundColor DarkGray
    $LibraryTracks[0] | Select-Object ratingKey, grandparentTitle, parentTitle, title, index | Format-List

    foreach ($Entry in ($Unmatched | Select-Object -First 3)) {
        Write-Host "--- CSV row: artist='$($Entry.artist)' album='$($Entry.album)' song='$($Entry.song)' TrackNo='$($Entry.TrackNo)'" -ForegroundColor Cyan
        $byArtist = @($LibraryTracks | Where-Object { $_.grandparentTitle -eq $Entry.artist })
        $bySong = @($LibraryTracks | Where-Object { $_.title -eq $Entry.song })
        $byAlbum = @($LibraryTracks | Where-Object { $_.parentTitle -eq $Entry.album })
        Write-Host "    exact artist matches: $($byArtist.Count)   exact song matches: $($bySong.Count)   exact album matches: $($byAlbum.Count)"
        if ($byArtist.Count -gt 0) {
            Write-Host "    that artist's tracks in Plex (first 3):" -ForegroundColor DarkGray
            $byArtist | Select-Object -First 3 | ForEach-Object { Write-Host "      album='$($_.parentTitle)' song='$($_.title)' index='$($_.index)'" }
        }
        else {
            $fuzzy = @($LibraryTracks | Where-Object { $_.grandparentTitle -like "*$($Entry.artist)*" }) | Select-Object -First 3
            if ($fuzzy) { Write-Host "    no exact artist match; closest by wildcard: $(($fuzzy | ForEach-Object { "'$($_.grandparentTitle)'" }) -join ', ')" -ForegroundColor Yellow }
            else { Write-Host "    artist not present in this library at all, even by wildcard." -ForegroundColor Yellow }
        }
    }
    Write-Host "Nothing to add - stopping before playlist creation." -ForegroundColor Red
    return
}

#Confirm before proceeding
$Proceed = Read-Host "Proceed with creating playlist '$PlaylistName' with $($Tracks.Count) tracks? (y/n)"
if ($Proceed -ne 'y') {
    Write-Host "Aborting playlist creation."
    return
}

#Get the Machine ID
Write-Host "Fetching Machine ID from Plex server"
$Response = Invoke-PlexRequest -Method "Get" -Endpoint "/identity"
$MachineID = $Response.MediaContainer.MachineIdentifier

#Create the playlist as the supplied account
Write-Host "Creating playlist '$PlaylistName'"
$Response = Invoke-PlexRequest -Method "Post" -Endpoint "/playlists?type=audio&title=$PlaylistName&smart=0&uri=server://$MachineID/com.plexapp.plugins.library"
$PlaylistKey = $Response.MediaContainer.Playlist.ratingKey

if ([string]::IsNullOrWhiteSpace($PlaylistKey)) {
    Write-Host "Playlist creation did not return a ratingKey." -ForegroundColor Red
    return
}

#Add the tracks to the playlist as the supplied account
Write-Host "Adding tracks to playlist '$PlaylistName'"
foreach ($Track in $Tracks) {
    $Response = Invoke-PlexRequest -Method "Put" -Endpoint "/playlists/$PlaylistKey/items?uri=server://$MachineID/com.plexapp.plugins.library/library/metadata/$Track"
    Write-Verbose "Response for adding ratingKey $Track is: $($Response.OuterXml)"
}

#Report back what this token can actually see
$Final = Invoke-PlexRequest -Method "Get" -Endpoint "/playlists/$PlaylistKey"
Write-Host "Playlist '$PlaylistName' (ratingKey $PlaylistKey) now contains $($Final.MediaContainer.Metadata.leafCount) track(s)" -ForegroundColor Green
