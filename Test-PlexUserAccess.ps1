<#
    Diagnostic for Import-PlexPlaylistV3. Read-only - creates nothing.
    Shows what a given token can actually see on the server.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [string] $PlexServer,
    [Parameter(Mandatory = $true)] [string] $Token,
    [int] $SectionKey = 4
)

$PlexURL = "http://" + $PlexServer + ":32400"

function Get-Raw {
    param([string]$Endpoint, [switch]$AsJson)
    $headers = @{ 'X-Plex-Token' = $Token }
    if ($AsJson) { $headers['Accept'] = 'application/json' }
    Invoke-WebRequest -Method Get -Uri "$PlexURL$Endpoint" -Headers $headers -UseBasicParsing
}

Write-Host "`n=== 1. Who does this token belong to? ===" -ForegroundColor Cyan
try {
    $r = Get-Raw -Endpoint "/" -AsJson
    $root = $r.Content | ConvertFrom-Json
    [pscustomobject]@{
        friendlyName    = $root.MediaContainer.friendlyName
        myPlexUsername  = $root.MediaContainer.myPlexUsername
        allowSync       = $root.MediaContainer.allowSync
        ownerFeatures   = if ($root.MediaContainer.PSObject.Properties.Name -contains 'ownerFeatures') { 'present (owner token)' } else { 'absent (likely shared/managed token)' }
    } | Format-List
}
catch { Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n=== 2. Which library sections can this token see? ===" -ForegroundColor Cyan
try {
    $r = Get-Raw -Endpoint "/library/sections" -AsJson
    Write-Host "Content-Type: $($r.Headers['Content-Type'])" -ForegroundColor DarkGray
    $secs = ($r.Content | ConvertFrom-Json).MediaContainer.Directory
    if (-not $secs) { Write-Host "No sections returned at all." -ForegroundColor Red }
    else { $secs | Select-Object key, type, title | Format-Table -AutoSize }
    Write-Host "Script is hardcoded to section $SectionKey. Confirm a MUSIC section above has key=$SectionKey." -ForegroundColor Yellow
}
catch { Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n=== 3. What comes back for section $SectionKey (type=10 / tracks)? ===" -ForegroundColor Cyan
try {
    $r = Get-Raw -Endpoint "/library/sections/$SectionKey/all?type=10" -AsJson
    Write-Host "HTTP $($r.StatusCode)   Content-Type: $($r.Headers['Content-Type'])" -ForegroundColor DarkGray
    Write-Host "Payload size: $($r.Content.Length) bytes" -ForegroundColor DarkGray

    if ("$($r.Headers['Content-Type'])" -notmatch 'json') {
        Write-Host "NOT JSON. Invoke-RestMethod would parse this as XML and .MediaContainer.Metadata would be null -> zero matches, no error." -ForegroundColor Red
        Write-Host ($r.Content.Substring(0, [Math]::Min(600, $r.Content.Length)))
    }
    else {
        $mc = ($r.Content | ConvertFrom-Json).MediaContainer
        Write-Host "MediaContainer.size      : $($mc.size)"
        Write-Host "MediaContainer.totalSize : $($mc.totalSize)"
        Write-Host "Metadata rows returned   : $($mc.Metadata.Count)"
        if ($mc.Metadata.Count -gt 0) {
            Write-Host "`nFirst 3 tracks as this token sees them:" -ForegroundColor Green
            $mc.Metadata | Select-Object -First 3 |
                Select-Object ratingKey, grandparentTitle, parentTitle, title, index | Format-List
        }
        else {
            Write-Host "Section is visible but returned ZERO tracks for this token." -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "A 401 here means the music library is not shared with this managed account." -ForegroundColor Yellow
}
