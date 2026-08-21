<#
    Compares two Plex tokens: who each one belongs to (via plex.tv, which IS
    token-scoped) and how many tracks each can see. Read-only.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [string] $PlexServer,
    [Parameter(Mandatory = $true)] [string] $AdminToken,
    [Parameter(Mandatory = $true)] [string] $ManagedToken,
    [int] $SectionKey = 4
)

function Get-TokenIdentity {
    param([string]$Token)
    # plex.tv resolves the token to its actual account - managed users included
    $headers = @{
        'X-Plex-Token'             = $Token
        'X-Plex-Client-Identifier' = 'ps-token-check'
        'X-Plex-Product'           = 'TokenCheck'
        'Accept'                   = 'application/json'
    }
    try {
        $u = Invoke-RestMethod -Method Get -Uri 'https://plex.tv/api/v2/user' -Headers $headers
        [pscustomobject]@{
            id       = $u.id
            title    = $u.title
            username = $u.username
            email    = $u.email
            restricted = $u.restricted
            home     = $u.home
        }
    }
    catch { [pscustomobject]@{ id = "LOOKUP FAILED: $($_.Exception.Message)" } }
}

function Get-TrackCount {
    param([string]$Token)
    $headers = @{ 'X-Plex-Token' = $Token; 'Accept' = 'application/json' }
    try {
        $r = Invoke-RestMethod -Method Get -Uri "http://${PlexServer}:32400/library/sections/$SectionKey/all?type=10" -Headers $headers
        "$($r.MediaContainer.Metadata.Count) tracks"
    }
    catch { "FAILED: $($_.Exception.Message)" }
}

foreach ($pair in @(@{ Name = 'AdminToken'; Value = $AdminToken }, @{ Name = 'ManagedToken'; Value = $ManagedToken })) {
    Write-Host "`n=== $($pair.Name) ===" -ForegroundColor Cyan
    Write-Host "last 4 chars: ...$($pair.Value.Substring([Math]::Max(0, $pair.Value.Length - 4)))" -ForegroundColor DarkGray
    Get-TokenIdentity -Token $pair.Value | Format-List
    Write-Host "section $SectionKey visibility: $(Get-TrackCount -Token $pair.Value)" -ForegroundColor Yellow
}

Write-Host "`nIf both blocks show the SAME id/title, the two tokens are the same account." -ForegroundColor Green
Write-Host "A managed user should show restricted=1 and a distinct id/title." -ForegroundColor Green
