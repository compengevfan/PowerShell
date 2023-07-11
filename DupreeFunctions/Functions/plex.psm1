Function Get-PlexTVShows {
    [CmdletBinding()]
    Param(
    )
 
    Import-Credentials

    if ($CredPlexToken) {
        $TVShows = @()
        $Token = $CredPlexToken.GetNetworkCredential().password
        $response = Invoke-RestMethod "http://jax-plms001.evorigin.com:32400/library/sections/1/all?X-Plex-Token=$Token" -Method "GET"

        foreach ($TVShow in $response.MediaContainer.Directory) {
            $TVShows += $TVShow.Title
        }
        Write-Host "$($TVShows.Count) TV Shows Found."
    }
    else {
        Write-Host "Plex token not found. Exiting."
    }
}

Function Get-PlexMovies {
    [CmdletBinding()]
    Param(
    )
 
    Import-Credentials

    if ($CredPlexToken) {
        $Movies = @()
        $Token = $CredPlexToken.GetNetworkCredential().password
        $response = Invoke-RestMethod "http://jax-plms001.evorigin.com:32400/library/sections/2/all?X-Plex-Token=$Token" -Method "GET"

        foreach ($Movie in $response.MediaContainer.Video) {
            $Movies += $Movie.Title
        }
        Write-Host "$($Movies.Count) Movies Found."
    }
    else {
        Write-Host "Plex token not found. Exiting."
    }
}