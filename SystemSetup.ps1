<#
.SYNOPSIS
 Bootstrap a new Windows or Linux machine to use this PowerShell profile.
.DESCRIPTION
 One-time setup: works out where this git repo lives, persists the environment
 variables the profile reports on, and copies the profile script into place for
 the PowerShell host you're running this from.

 Everything the profile itself needs beyond that (modules, git, Claude Code) is
 optional and the profile already degrades gracefully when they're missing, so
 this script doesn't install them - it just gets the profile loading.

 After this runs once, use the profile's own Sync-Profile function to deploy it
 to every other PowerShell host (ISE, VS Code, Windows PowerShell vs PowerShell 7)
 on the machine.
#>
[CmdletBinding()]
param()

# Linux only ever runs PowerShell 7+, where $IsWindows exists. On Windows
# PowerShell 5.1, $IsWindows doesn't exist at all, so its absence means Windows.
$OnWindows = if ($null -ne $IsWindows) { $IsWindows } else { $true }

Write-Host "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition)) on $(if ($OnWindows) { 'Windows' } else { 'Linux/macOS' })`n"

function Set-PersistentEnvironmentVariable {
	param(
		[Parameter(Mandatory)][string] $Name,
		[Parameter(Mandatory)][string] $Value
	)

	Set-Item -Path "Env:$Name" -Value $Value

	if ($OnWindows) {
		[System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::User)
		return
	}

	# No per-user environment store on Linux/macOS outside of shell startup files,
	# so persist it the same way a user would by hand: export it from ~/.profile.
	$RcFile = Join-Path $HOME '.profile'
	$ExportLine = "export $Name=`"$Value`""
	$Existing = if (Test-Path -LiteralPath $RcFile) { Get-Content -LiteralPath $RcFile } else { @() }
	$Existing = @($Existing | Where-Object { $_ -notmatch "^export $Name=" })
	Set-Content -LiteralPath $RcFile -Value ($Existing + $ExportLine)
}

# --- githome --------------------------------------------------------------
# This script lives at $githome\PowerShell\SystemSetup.ps1, so githome is just
# its own grandparent directory. No need to guess or prompt for it.
$GitHome = Split-Path -Parent $PSScriptRoot
Write-Host "Git home: $GitHome" -ForegroundColor Green
Set-PersistentEnvironmentVariable -Name 'githome' -Value $GitHome

# --- optional homes ---------------------------------------------------------
# Purely informational to the profile, so only ask, and skip on a blank answer.
function Set-OptionalHome {
	param([string] $Name, [string] $Prompt)

	$Current = [System.Environment]::GetEnvironmentVariable($Name)
	if ($Current) {
		Write-Host "$Name already set: $Current" -ForegroundColor Green
		return
	}
	$Value = Read-Host "$Prompt (press Enter to skip)"
	if ($Value) { Set-PersistentEnvironmentVariable -Name $Name -Value $Value }
}

Set-OptionalHome -Name 'giteahome' -Prompt 'Path to the Gitea skills repo'
Set-OptionalHome -Name 'dropboxhome' -Prompt 'Path to Dropbox'
Set-OptionalHome -Name 'protonhome' -Prompt 'Path to Proton Drive'

# --- deploy the profile -----------------------------------------------------
$ProfileSource = Join-Path $GitHome 'PowerShell\Profile\Microsoft.PowerShell_profile.ps1'
if (-not (Test-Path -LiteralPath $ProfileSource)) {
	Write-Host "`nProfile source not found: $ProfileSource" -ForegroundColor Red
	return
}

$ProfileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path -LiteralPath $ProfileDir)) {
	New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# Cover every host that shares this profile directory. ISE only exists on
# Windows; VS Code's PowerShell extension looks for its own name everywhere.
$ProfileNames = @('Microsoft.PowerShell_profile.ps1', 'Microsoft.VSCode_profile.ps1')
if ($OnWindows) { $ProfileNames += 'Microsoft.PowerShellISE_profile.ps1' }

Write-Host ''
foreach ($Name in $ProfileNames) {
	$Destination = Join-Path $ProfileDir $Name
	Copy-Item -LiteralPath $ProfileSource -Destination $Destination -Force
	Write-Host "Installed profile: $Destination" -ForegroundColor Green
}

# --- report on optional companions -----------------------------------------
# Not installed here - the profile already handles their absence gracefully.
Write-Host ''
foreach ($Command in 'git', 'claude') {
	if (Get-Command $Command -ErrorAction SilentlyContinue) {
		Write-Host "$Command is installed." -ForegroundColor Green
	}
	else {
		Write-Host "$Command was not found on PATH." -ForegroundColor Yellow
	}
}

Write-Host "`nDone. Restart PowerShell to load the new profile." -ForegroundColor Cyan
Write-Host "Once it's loaded, run Sync-Profile to deploy it to any other PowerShell host on this machine." -ForegroundColor Cyan
