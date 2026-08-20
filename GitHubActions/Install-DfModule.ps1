<#
.SYNOPSIS
    Installs DupreeFunctions from git into the system-wide PowerShell module paths.

.DESCRIPTION
    Runs ON the target machine, as root (Linux) or as a local administrator (Windows).
    Maintains a staging clone of the repo and copies the DupreeFunctions folder into a
    versioned module directory, so PowerShell always resolves the highest version and a
    rollback is just deleting a folder.

    Windows installs to both the Windows PowerShell 5.1 and PowerShell 7 module roots.
    Linux installs to the PowerShell 7 module root.

    Safe to run repeatedly. If the version in the manifest is already installed the copy
    is skipped unless -Force is supplied.

.EXAMPLE
    ./Install-DfModule.ps1

.EXAMPLE
    ./Install-DfModule.ps1 -Branch master -Force
#>
[CmdletBinding()]
Param(
    [string] $RepoUrl = "https://github.com/compengevfan/PowerShell.git",
    [string] $Branch = "master",
    [string] $StagingPath,
    [switch] $Force
)

$ErrorActionPreference = "Stop"

#$IsWindows does not exist in Windows PowerShell 5.1, where it is always Windows
$OnWindows = if ($null -eq $IsWindows) { $true } else { $IsWindows }

if (!$StagingPath) {
    $StagingPath = if ($OnWindows) { "C:\ProgramData\DupreeFunctions\repo" } else { "/opt/dupreefunctions/repo" }
}

#System wide module roots. Windows gets both editions, Linux gets PowerShell 7 only.
$ModuleRoots = if ($OnWindows) {
    @(
        (Join-Path $env:ProgramFiles "WindowsPowerShell\Modules")
        (Join-Path $env:ProgramFiles "PowerShell\Modules")
    )
}
else {
    @("/usr/local/share/powershell/Modules")
}

Write-Host "Installing DupreeFunctions on $([System.Net.Dns]::GetHostName())"

#Refresh the staging clone
if (Test-Path (Join-Path $StagingPath ".git")) {
    Write-Host "Refreshing staging clone at $StagingPath"
    #--quiet throughout because this runs inside a remoting session, where anything git
    #writes to stderr becomes a remote error record and anything it writes to stdout is
    #collected as pipeline output. Both corrupt the caller. Real failures are still caught
    #by the exit code checks below, and genuine git errors still reach stderr.
    git -C $StagingPath fetch --quiet origin --prune
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed in $StagingPath" }
    git -C $StagingPath reset --quiet --hard "origin/$Branch"
    if ($LASTEXITCODE -ne 0) { throw "git reset failed in $StagingPath" }
    git -C $StagingPath clean -qfd
    if ($LASTEXITCODE -ne 0) { throw "git clean failed in $StagingPath" }

    #--quiet drops the commit git would otherwise report, so state it deliberately
    $DeployedCommit = git -C $StagingPath rev-parse --short HEAD
    Write-Host "  now at $DeployedCommit"
}
else {
    #An existing directory with content but no .git makes git clone fail with a confusing
    #message, which is what leftovers from a hand rolled install look like
    if ((Test-Path $StagingPath) -and (Get-ChildItem $StagingPath -Force | Select-Object -First 1)) {
        throw "$StagingPath already has content but is not a git clone. Remove it and run this again."
    }

    Write-Host "Cloning $RepoUrl to $StagingPath"
    $StagingParent = Split-Path $StagingPath -Parent
    if (!(Test-Path $StagingParent)) { New-Item -ItemType Directory -Path $StagingParent -Force | Out-Null }
    git clone --quiet --branch $Branch $RepoUrl $StagingPath
    if ($LASTEXITCODE -ne 0) { throw "git clone of $RepoUrl failed" }
}

#Read the version being deployed straight from the manifest
$SourceDir = Join-Path $StagingPath "DupreeFunctions"
$ManifestPath = Join-Path $SourceDir "DupreeFunctions.psd1"
if (!(Test-Path $ManifestPath)) { throw "Module manifest not found at $ManifestPath" }

$Version = (Import-PowerShellDataFile $ManifestPath).ModuleVersion
if (!$Version) { throw "Could not read ModuleVersion from $ManifestPath" }
Write-Host "Deploying DupreeFunctions $Version"

foreach ($Root in $ModuleRoots) {
    #Nested Join-Path rather than an embedded separator, so this stays correct on Linux
    $ModuleDir = Join-Path $Root "DupreeFunctions"
    $Destination = Join-Path $ModuleDir $Version

    #Bootstrap creates this and hands it to the deploy account, so its absence is the usual
    #cause of a permission failure further down
    if (!(Test-Path $ModuleDir)) {
        throw "$ModuleDir does not exist. Run Bootstrap-DfDeployTarget.ps1 on this host first."
    }

    if ((Test-Path $Destination) -and !$Force) {
        Write-Host "  $Version already present in $Root, skipping"
        continue
    }

    if (Test-Path $Destination) {
        Write-Host "  Replacing existing $Version in $Root"
        Remove-Item $Destination -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -Path (Join-Path $SourceDir "*") -Destination $Destination -Recurse -Force
    Write-Host "  Installed to $Destination"
}

#Confirm PowerShell can actually see what was just installed
$Installed = Get-Module -ListAvailable DupreeFunctions |
    Where-Object { $_.Version.ToString() -eq $Version }

if (!$Installed) { throw "DupreeFunctions $Version was copied but is not discoverable on this host" }

Write-Host "DupreeFunctions $Version installed successfully"
