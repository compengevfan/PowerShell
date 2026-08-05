<#PSScriptInfo

.VERSION 4.5.0

.GUID b53cae85-1769-4697-ba24-a6fd87efb453

.AUTHOR cdupree

.COMPANYNAME

.COPYRIGHT

.TAGS profile prompt

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
4.5.0 Sync-ClaudeSkills pulls $giteahome\skills and mirrors it into
      ~\.claude\skills; cld runs it before showing the menu. Mirror means a skill
      removed from the repo is removed locally. Skipped entirely when
      $env:giteahome is not set, and the pull is bounded so an unreachable Gitea
      cannot hang the launcher.

4.4.0 A default shell now opens in $githome, so Claude Code starts in a directory
      it already trusts. Deliberate working directories (Open PowerShell here, a
      VS Code workspace, a configured startingDirectory) are left alone.
      Set-ClaudeDirectoryTrust pre-accepts the workspace-trust dialog for new
      claudthings projects; cld calls it before launching. PowerShell 7+ only.

4.3.0 All four home paths now report identically: Git, Gitea, Dropbox and Proton
      each say so when their environment variable is empty.

4.2.0 Banner reports Proton home from $env:protonhome, quiet when unset like
      Dropbox home.

4.1.0 Banner reports Gitea home from $env:giteahome, alongside Git home.

4.0.0 Self-contained: this one file is the whole setup, so copying it to a new
      machine is the entire install. Deployment no longer needs DupreeFunctions
      (Sync-Profile replaces Sync-DfProfileScript and finds its own source).
      Absorbed the claudthings launcher: Invoke-ClaudePicker (alias cld) picks a
      project under ~\claudthings and starts Claude Code there, Test-ClaudeSkills
      reconciles ~\.claude\skills against SKILLS.md, Initialize-ClaudeThings lays
      the folders down. All of it no-ops politely where Claude Code is absent.
      Permission bypass is opt-in per launch (-Yolo), never the default.

3.0.0 Nothing in the profile can abort the load any more (a missing module is
      reported, not thrown). Module imports happen once instead of twice.
      Machine detection reads the registry instead of doing a DNS lookup.
      .NET table understands 4.8.1 and anything newer. PowerCLI version no
      longer breaks when several versions are side by side. Prompt gained a
      git branch, elevation marker and failure marker, and now returns a
      single string so PSReadLine can redraw it. PSReadLine is configured.
      Set $env:PSPROFILE_QUIET = '1' to start without the banner.

.PRIVATEDATA

#>

# A floor, not a pin: -Version means "this version or newer", so this covers
# Windows PowerShell 5.1 and every PowerShell 7.x. Nothing below runs 5.1-only
# or 7-only syntax; version-specific features are feature-detected at the point
# of use rather than branched on $PSVersionTable.
#Requires -Version 5.1

<#

.DESCRIPTION
 PowerShell profile. One file serves Windows PowerShell 5.1, PowerShell 7+,
 the ISE and VS Code; run Sync-Profile to copy it to all of them.

 Self-contained by design: everything here degrades to a message rather than an
 error when a dependency is missing, so this file can be dropped on any machine
 - personal or work, with or without DupreeFunctions, with or without Claude
 Code - and simply work.

#>
Param()

$ProfileTimer = [System.Diagnostics.Stopwatch]::StartNew()
$ProfileQuiet = [bool]$env:PSPROFILE_QUIET

# Captured now, while $PSCommandPath is unambiguous, so Sync-Profile can fall back
# to "the file I was loaded from" without depending on scope-chain luck later.
$global:ProfileSourcePath = $PSCommandPath

#region Helpers ---------------------------------------------------------------

# ISE has no virtual terminal, so the prompt falls back to plain text there.
$global:ProfileAnsi = @{}
$SupportsVT = $false
try { $SupportsVT = [bool]$Host.UI.SupportsVirtualTerminal } catch { }
$Esc = [char]27
$Palette = [ordered]@{
	Reset = '0'; Dim = '90'; Red = '91'; Green = '92'
	Yellow = '93'; Cyan = '96'; Magenta = '95'
}
foreach ($Color in $Palette.GetEnumerator()) {
	$global:ProfileAnsi[$Color.Key] = if ($SupportsVT) { "$Esc[$($Color.Value)m" } else { '' }
}

$global:ProfileIsAdmin = $false
try {
	$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$global:ProfileIsAdmin = ([Security.Principal.WindowsPrincipal]$Identity).IsInRole(
		[Security.Principal.WindowsBuiltInRole]::Administrator)
}
catch { }

function Write-ProfileStatus {
	param(
		[string] $Label,
		[string] $Value,
		[System.ConsoleColor] $Color = [System.ConsoleColor]::Gray
	)
	if ($ProfileQuiet) { return }
	Write-Host ('  {0,-16}' -f $Label) -NoNewline -ForegroundColor DarkGray
	Write-Host $Value -ForegroundColor $Color
}

function Get-DotNetFrameworkVersion {
	# Highest release number that is <= what is installed wins, so builds newer
	# than this table still report the last version we know about.
	$Release = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' `
			-Name Release -ErrorAction SilentlyContinue).Release
	if (-not $Release) { return $null }

	$Releases = @(
		@(533320, '4.8.1'), @(528040, '4.8'), @(461808, '4.7.2'), @(461308, '4.7.1'),
		@(460798, '4.7'), @(394802, '4.6.2'), @(394254, '4.6.1'), @(393295, '4.6'),
		@(379893, '4.5.2'), @(378675, '4.5.1'), @(378389, '4.5')
	)
	foreach ($Entry in $Releases) {
		if ($Release -ge $Entry[0]) { return '{0} (release {1})' -f $Entry[1], $Release }
	}
	return "unrecognized release $Release"
}

function Get-ComputerDomain {
	# The computer's own domain, not the logon domain, and no network round trip.
	$TcpipParameters = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
		-ErrorAction SilentlyContinue
	foreach ($Name in 'Domain', 'NV Domain') {
		if ($TcpipParameters -and $TcpipParameters.$Name) { return [string]$TcpipParameters.$Name }
	}
	if ($env:USERDNSDOMAIN) { return $env:USERDNSDOMAIN }
	try { return [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName -replace '^[^.]+\.?', '' }
	catch { return '' }
}

function Import-ProfileModule {
	param([Parameter(Mandatory)][string] $Name)

	try {
		Import-Module -Name $Name -ErrorAction Stop
		$Module = Get-Module -Name $Name | Select-Object -First 1
		Write-ProfileStatus $Name ('{0} loaded' -f $Module.Version) Green
		return $true
	}
	catch {
		Write-ProfileStatus $Name "not loaded - $($_.Exception.Message)" Red
		return $false
	}
}

#endregion

#region Environment -----------------------------------------------------------

Write-ProfileStatus 'PowerShell' ('{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition) Cyan

# RuntimeInformation arrived in .NET Framework 4.7.1, so Windows PowerShell on an
# older box has no such type. Fall back to the CLR version it always exposes.
$Runtime = try { [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription }
catch { 'CLR {0}' -f [System.Environment]::Version }
Write-ProfileStatus 'Runtime' $Runtime

$FrameworkVersion = Get-DotNetFrameworkVersion
if ($FrameworkVersion) { Write-ProfileStatus '.NET Framework' $FrameworkVersion }

$ComputerDomain = Get-ComputerDomain
$Fqdn = if ($ComputerDomain) { "$env:COMPUTERNAME.$ComputerDomain".ToLower() } else { $env:COMPUTERNAME }
Write-ProfileStatus 'Host' "$Fqdn$(if ($global:ProfileIsAdmin) { ' (elevated)' })" Cyan

# Mirrored as variables, not just env vars: Sync-DfProfileScript reads $githome,
# and having $githome / $giteahome / $dropboxhome to hand is useful at the prompt.
$global:githome = $env:githome
if ($githome) { Write-ProfileStatus 'Git home' $githome Green }
else { Write-ProfileStatus 'Git home' 'not set - $env:githome is empty' Yellow }

$global:giteahome = $env:giteahome
if ($giteahome) { Write-ProfileStatus 'Gitea home' $giteahome Green }
else { Write-ProfileStatus 'Gitea home' 'not set - $env:giteahome is empty' Yellow }

$global:dropboxhome = $env:dropboxhome
if ($dropboxhome) { Write-ProfileStatus 'Dropbox home' $dropboxhome Green }
else { Write-ProfileStatus 'Dropbox home' 'not set - $env:dropboxhome is empty' Yellow }

$global:protonhome = $env:protonhome
if ($protonhome) { Write-ProfileStatus 'Proton home' $protonhome Green }
else { Write-ProfileStatus 'Proton home' 'not set - $env:protonhome is empty' Yellow }

$PowerCLI = Get-Module -ListAvailable VMware.Vim | Sort-Object Version -Descending | Select-Object -First 1
if ($PowerCLI) { Write-ProfileStatus 'PowerCLI' ('{0}.{1}' -f $PowerCLI.Version.Major, $PowerCLI.Version.Minor) Green }
else { Write-ProfileStatus 'PowerCLI' 'not installed' Yellow }

# Version comes free from the executable's file metadata. Never shell out to
# `claude --version` here - that alone costs more than this whole profile load.
# Machines without Claude Code simply do not get the line.
$ClaudeCommand = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ClaudeCommand) {
	$ClaudeVersion = 'installed'
	if ($ClaudeCommand.Version) {
		$ClaudeVersion = if ($ClaudeCommand.Version.Build -ge 0) {
			'{0}.{1}.{2}' -f $ClaudeCommand.Version.Major, $ClaudeCommand.Version.Minor, $ClaudeCommand.Version.Build
		}
		else { $ClaudeCommand.Version.ToString() }
	}
	Write-ProfileStatus 'Claude Code' "$ClaudeVersion - 'cld' picks a project" Green
}

# Land in $githome so Claude Code starts somewhere it already trusts, instead of
# wherever the shell happened to open. Only on a DEFAULT launch: "Open PowerShell
# here", a VS Code workspace folder and any configured startingDirectory all begin
# somewhere other than $HOME, and those choices are deliberate - leave them alone.
if ($githome -and (Test-Path -LiteralPath $githome)) {
	if ((Get-Location).Path -eq $HOME) {
		Set-Location -LiteralPath $githome
		Write-ProfileStatus 'Working dir' $githome Cyan
	}
}

if ($ComputerDomain -like '*evorigin.com') {
	if (Import-ProfileModule 'DupreeFunctions') {
		try {
			# 6> swallows the module's own Write-Host banner; this line replaces it.
			Import-DfCredentials 6> $null | Out-Null
			Write-ProfileStatus 'Credentials' 'imported' Green
		}
		catch {
			Write-ProfileStatus 'Credentials' "import failed - $($_.Exception.Message)" Red
		}
	}
}
else {
	Import-ProfileModule 'DC.Automation' | Out-Null
}

#endregion

#region PSReadLine ------------------------------------------------------------

# Absent in the ISE, and too old on stock Windows PowerShell to predict.
$PSReadLine = Get-Module -Name PSReadLine
if ($PSReadLine) {
	try {
		Set-PSReadLineOption -EditMode Windows -BellStyle None -HistoryNoDuplicates `
			-HistorySearchCursorMovesToEnd -MaximumHistoryCount 8192
		Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
		Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
		Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
		Set-PSReadLineKeyHandler -Key 'Ctrl+w' -Function BackwardKillWord
		if ($PSReadLine.Version -ge [version]'2.2.0') {
			Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
		}
	}
	catch {
		Write-ProfileStatus 'PSReadLine' "not configured - $($_.Exception.Message)" Yellow
	}
}

#endregion

#region Prompt ----------------------------------------------------------------

function Get-PromptGitBranch {
	param([string] $Path)

	$Directory = $Path
	while ($Directory) {
		$GitPath = Join-Path $Directory '.git'
		if (Test-Path -LiteralPath $GitPath) {
			# In a worktree or submodule .git is a file pointing at the real one.
			if (Test-Path -LiteralPath $GitPath -PathType Leaf) {
				$Pointer = Get-Content -LiteralPath $GitPath -TotalCount 1
				if ($Pointer -match '^gitdir:\s*(.+)$') {
					$GitPath = $Matches[1].Trim()
					if (-not [System.IO.Path]::IsPathRooted($GitPath)) { $GitPath = Join-Path $Directory $GitPath }
				}
			}
			$Head = Join-Path $GitPath 'HEAD'
			if (Test-Path -LiteralPath $Head) {
				$Ref = Get-Content -LiteralPath $Head -TotalCount 1
				if ($Ref -match '^ref:\s*refs/heads/(.+)$') { return $Matches[1] }
				if ($Ref) { return $Ref.Substring(0, [Math]::Min(7, $Ref.Length)) }  # detached HEAD
			}
			return $null
		}
		$Parent = Split-Path -Parent $Directory
		if (-not $Parent -or $Parent -eq $Directory) { break }
		$Directory = $Parent
	}
	return $null
}

function Get-PromptPath {
	param([string] $Path)

	if ($HOME -and $Path.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
		$Path = '~' + $Path.Substring($HOME.Length)
	}
	$Segments = $Path.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)
	if ($Segments.Count -le 3) { return $Path }
	return '{0}\...\{1}\{2}' -f $Segments[0], $Segments[-2], $Segments[-1]
}

function global:prompt {
	$Succeeded = $?   # must stay the first statement

	$Ansi = $global:ProfileAnsi
	$Location = $ExecutionContext.SessionState.Path.CurrentLocation
	$IsFileSystem = $Location.Provider.Name -eq 'FileSystem'
	$FullPath = $Location.Path
	$ShortPath = if ($IsFileSystem) { Get-PromptPath -Path $FullPath } else { $FullPath }

	$vCenter = ''
	if ($global:DefaultVIServers) {
		$vCenter = (($global:DefaultVIServers | Where-Object { $_.IsConnected }).Name) -join ','
	}

	$Branch = if ($IsFileSystem) { Get-PromptGitBranch -Path $FullPath } else { $null }

	# Invoke-ClaudePicker pins the tab to a project name. Without this check the very
	# next prompt render would wipe it the moment Claude Code exits.
	if ($global:ProfilePinnedTitle) {
		$Title = $global:ProfilePinnedTitle
	}
	else {
		$Title = '{0}{1} {2}' -f $env:USERNAME, $(if ($global:ProfileIsAdmin) { ' (Admin)' }), $FullPath
		if ($vCenter) { $Title += " - $vCenter" }
	}
	try { $Host.UI.RawUI.WindowTitle = $Title } catch { }

	$Line = New-Object System.Text.StringBuilder
	[void]$Line.Append($Ansi.Dim).Append($env:USERNAME)
	if ($global:ProfileIsAdmin) { [void]$Line.Append($Ansi.Red).Append('#') }
	[void]$Line.Append(' ').Append($Ansi.Yellow).Append($ShortPath)
	if ($Branch) { [void]$Line.Append(' ').Append($Ansi.Cyan).Append('(').Append($Branch).Append(')') }
	if ($vCenter) { [void]$Line.Append(' ').Append($Ansi.Magenta).Append('[').Append($vCenter).Append(']') }
	if (-not $Succeeded) {
		# Only trust $LASTEXITCODE when the last command actually failed, otherwise
		# a stale code from an old native command sticks to every prompt.
		$Marker = if ($global:LASTEXITCODE) { "!$global:LASTEXITCODE" } else { '!' }
		[void]$Line.Append(' ').Append($Ansi.Red).Append($Marker)
	}
	if ($NestedPromptLevel -gt 0) { [void]$Line.Append(' ').Append($Ansi.Dim).Append('+' * $NestedPromptLevel) }
	[void]$Line.Append($Ansi.Yellow).Append('>').Append($Ansi.Reset).Append(' ')

	return $Line.ToString()
}

#endregion

#region Claude Code -----------------------------------------------------------

# Absorbed from a friend's install-claudthings.ps1 / claude-pick.ps1. Adapted to
# live inside a profile: no `exit` (it would kill the shell), no $PSScriptRoot
# (it differs per host), state anchored to the projects root, and nothing here
# runs at load time - these are definitions only.

$global:ClaudeThingsRoot = Join-Path $HOME 'claudthings'
$global:ClaudeThingsArchive = Join-Path $HOME 'claudoldignore'

function Get-ClaudeCommand {
	# Single choke point so a machine without Claude Code says so once, instead of
	# throwing CommandNotFoundException from somewhere deeper in a menu.
	$Command = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
	if (-not $Command) {
		Write-Host "Claude Code is not installed on this machine (no 'claude' on PATH)." -ForegroundColor Yellow
		Write-Host '  Everything else in this profile still works.' -ForegroundColor DarkGray
		return $null
	}
	return $Command
}

function Test-ProfileInteractive {
	# Read-Host against a redirected stdin either throws or blocks forever, so the
	# menu-driven helpers refuse up front rather than wedging an agent shell or a
	# scheduled task. The ISE has no console at all, hence the catch.
	if (-not [System.Environment]::UserInteractive) { return $false }
	try { if ([System.Console]::IsInputRedirected) { return $false } } catch { }
	return $true
}

function Clear-ProfilePinnedTitle {
	$global:ProfilePinnedTitle = $null
	Remove-Item Env:\CLAUDE_CODE_DISABLE_TERMINAL_TITLE -ErrorAction SilentlyContinue
}

function Get-ClaudeSkillSignature {
	# Relative path + content hash for every file, so a comparison catches edits,
	# additions and removals anywhere in the skill folder - not just timestamps,
	# which a fresh git checkout rewrites anyway.
	param([string] $Path)

	Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
		Sort-Object FullName |
		ForEach-Object {
			'{0}|{1}' -f $_.FullName.Substring($Path.Length).TrimStart('\'),
			(Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash
		}
}

function Sync-ClaudeSkills {
	<#
	.SYNOPSIS
	 Pull the Gitea skills repo and mirror it into ~\.claude\skills.
	.DESCRIPTION
	 Entirely predicated on $env:giteahome. Without it there is no repo to sync
	 from and the whole thing is skipped. The destination is mirrored, so a skill
	 removed from the repo is removed locally too.
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[string] $Repo = $(if ($global:giteahome) { Join-Path $global:giteahome 'skills' }),
		[string] $Destination = (Join-Path $HOME '.claude\skills'),
		# A pull against an unreachable host would otherwise hang the launcher for
		# as long as TCP takes to give up.
		[int] $TimeoutSeconds = 20
	)

	if (-not $Repo) {
		Write-Verbose 'No $giteahome - skipping skills sync.'
		return
	}
	if (-not (Test-Path -LiteralPath $Repo)) {
		Write-Host "Skills repo not found: $Repo" -ForegroundColor Yellow
		return
	}

	# --- pull -------------------------------------------------------------
	if (Test-Path -LiteralPath (Join-Path $Repo '.git')) {
		if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
			Write-Host 'git is not on PATH - syncing whatever is already checked out.' -ForegroundColor Yellow
		}
		else {
			$Job = Start-Job -ScriptBlock {
				param($RepoPath)
				$Text = & git -C $RepoPath pull --ff-only 2>&1 | Out-String
				[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $Text }
			} -ArgumentList $Repo

			if (Wait-Job -Job $Job -Timeout $TimeoutSeconds) {
				$Result = Receive-Job -Job $Job
				if ($Result.ExitCode -ne 0) {
					Write-Host "git pull failed - using the local checkout." -ForegroundColor Yellow
					Write-Host ('  ' + $Result.Output.Trim()) -ForegroundColor DarkGray
				}
			}
			else {
				Stop-Job -Job $Job -WhatIf:$false
				Write-Host "git pull timed out after ${TimeoutSeconds}s - using the local checkout." -ForegroundColor Yellow
			}
			# Job cleanup is bookkeeping, not the operation being confirmed - without
			# -WhatIf:$false a dry run leaves the job behind and prints noise about it.
			Remove-Job -Job $Job -Force -WhatIf:$false
		}
	}

	# --- mirror -----------------------------------------------------------
	if (-not (Test-Path -LiteralPath $Destination)) {
		New-Item -ItemType Directory -Path $Destination -Force | Out-Null
	}

	# A skill is a folder with a SKILL.md - same test Test-ClaudeSkills uses. This
	# is why the repo's root README.md is not copied: it is not a skill.
	$Source = @(Get-ChildItem -LiteralPath $Repo -Directory -Force -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -notlike '.*' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')) })
	$Existing = @(Get-ChildItem -LiteralPath $Destination -Directory -Force -ErrorAction SilentlyContinue)

	$Added = 0; $Updated = 0; $Removed = 0; $Same = 0

	foreach ($Skill in $Source) {
		$Target = Join-Path $Destination $Skill.Name
		# Counted before the ShouldProcess guard so -WhatIf reports real intent
		# rather than the zeroes a skipped operation would leave behind.
		if (Test-Path -LiteralPath $Target) {
			$SourceSignature = (Get-ClaudeSkillSignature $Skill.FullName) -join "`n"
			$TargetSignature = (Get-ClaudeSkillSignature $Target) -join "`n"
			if ($SourceSignature -eq $TargetSignature) { $Same++; continue }
			$Updated++
			if ($PSCmdlet.ShouldProcess($Target, 'Update skill')) {
				Remove-Item -LiteralPath $Target -Recurse -Force
				Copy-Item -LiteralPath $Skill.FullName -Destination $Target -Recurse -Force
				Write-Host "  updated  $($Skill.Name)" -ForegroundColor Yellow
			}
		}
		else {
			$Added++
			if ($PSCmdlet.ShouldProcess($Target, 'Add skill')) {
				Copy-Item -LiteralPath $Skill.FullName -Destination $Target -Recurse -Force
				Write-Host "  added    $($Skill.Name)" -ForegroundColor Green
			}
		}
	}

	# Mirror means removals propagate: a skill dropped from the repo goes here too.
	foreach ($Stale in $Existing) {
		if ($Source.Name -contains $Stale.Name) { continue }
		$Removed++
		if ($PSCmdlet.ShouldProcess($Stale.FullName, 'Remove skill not in repo')) {
			Remove-Item -LiteralPath $Stale.FullName -Recurse -Force
			Write-Host "  removed  $($Stale.Name) (not in repo)" -ForegroundColor Red
		}
	}

	if ($Added -or $Updated -or $Removed) {
		Write-Host ("Skills: {0} added, {1} updated, {2} removed, {3} unchanged." -f
			$Added, $Updated, $Removed, $Same) -ForegroundColor Cyan
	}
	else {
		Write-Host ("Skills: in sync ({0})." -f $Same) -ForegroundColor DarkGray
	}
}

function Set-ClaudeDirectoryTrust {
	<#
	.SYNOPSIS
	 Mark a directory as trusted so Claude Code skips its workspace-trust dialog.
	.DESCRIPTION
	 There is no supported CLI for this - `claude project` only offers `purge` - so
	 this edits Claude Code's own ~\.claude.json. That file belongs to Claude Code
	 and it rewrites it on its own schedule, so a session running concurrently can
	 overwrite this change. The failure mode is benign: the flag is lost and the
	 dialog appears once, which is the behaviour without this function at all.
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(Mandatory)][string] $Path,
		# Overridable so this can be exercised against a copy of the config.
		[string] $ConfigPath = (Join-Path $HOME '.claude.json')
	)

	# ConvertFrom-Json -AsHashtable is PowerShell 6+. It matters here beyond
	# convenience: it returns a case-SENSITIVE OrderedHashtable, and this file can
	# hold keys differing only by case (c:/Git/Ansible and C:/Git/Ansible). Plain
	# ConvertFrom-Json refuses the file outright for exactly that reason.
	if ($PSVersionTable.PSVersion.Major -lt 6) {
		Write-Host 'Set-ClaudeDirectoryTrust needs PowerShell 7+ (ConvertFrom-Json -AsHashtable).' -ForegroundColor Yellow
		return
	}

	if (-not (Test-Path -LiteralPath $ConfigPath)) {
		Write-Verbose "No Claude Code config at $ConfigPath - nothing to trust."
		return
	}

	# Match the key style already in the file: absolute, forward slashes.
	$Key = (Resolve-Path -LiteralPath $Path).Path -replace '\\', '/'

	try {
		$Raw = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
		$Config = $Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
	}
	catch {
		Write-Host "Could not read $ConfigPath - $($_.Exception.Message)" -ForegroundColor Yellow
		return
	}

	if (-not $Config.ContainsKey('projects')) { $Config['projects'] = [ordered]@{} }
	if ($Config['projects'][$Key] -and $Config['projects'][$Key]['hasTrustDialogAccepted']) {
		Write-Verbose "$Key is already trusted."
		return
	}

	$KeyCountBefore = $Config.Keys.Count
	$ProjectCountBefore = $Config['projects'].Keys.Count

	if (-not $Config['projects'][$Key]) { $Config['projects'][$Key] = [ordered]@{} }
	$Config['projects'][$Key]['hasTrustDialogAccepted'] = $true

	# Depth 100 because the default of 2 would silently flatten most of this file.
	$Updated = $Config | ConvertTo-Json -Depth 100

	# Prove the serialized result still parses and lost nothing before it replaces
	# a 45 KB file that Claude Code depends on.
	try {
		$Check = $Updated | ConvertFrom-Json -AsHashtable -ErrorAction Stop
	}
	catch {
		Write-Host 'Refusing to write: the updated config did not parse back.' -ForegroundColor Red
		return
	}
	if ($Check.Keys.Count -lt $KeyCountBefore -or $Check['projects'].Keys.Count -lt $ProjectCountBefore) {
		Write-Host ('Refusing to write: keys would drop from {0}/{1} to {2}/{3}.' -f
			$KeyCountBefore, $ProjectCountBefore, $Check.Keys.Count, $Check['projects'].Keys.Count) -ForegroundColor Red
		return
	}

	if (-not $PSCmdlet.ShouldProcess($Key, 'Trust directory in Claude Code')) { return }

	try {
		Copy-Item -LiteralPath $ConfigPath -Destination ('{0}.bak-{1}' -f $ConfigPath, (Get-Date -Format 'yyyyMMdd-HHmmss')) -ErrorAction Stop
		# Write then rename, to keep the window where the real file is mid-write as
		# small as possible - Claude Code may be writing this file too.
		$Temp = '{0}.tmp-{1}' -f $ConfigPath, [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
		Set-Content -LiteralPath $Temp -Value $Updated -Encoding utf8 -ErrorAction Stop
		Move-Item -LiteralPath $Temp -Destination $ConfigPath -Force -ErrorAction Stop
		Write-Host "Trusted in Claude Code: $Key" -ForegroundColor DarkGray
	}
	catch {
		Write-Host "Could not update $ConfigPath - $($_.Exception.Message)" -ForegroundColor Yellow
	}
}

function Get-ClaudeProjectDescription {
	param([string] $Path)

	$Markdown = Join-Path $Path 'CLAUDE.md'
	if (-not (Test-Path -LiteralPath $Markdown)) { return '' }

	# Runs once per project on every menu redraw, and the heading is always near
	# the top, so there is no reason to read the whole file.
	foreach ($Line in (Get-Content -LiteralPath $Markdown -TotalCount 40 -ErrorAction SilentlyContinue)) {
		if ($Line.Trim() -match '^#{1,6}\s+(.+)$') {
			$Description = $Matches[1].Trim()
			if ($Description.Length -gt 48) { $Description = $Description.Substring(0, 45) + '...' }
			return $Description
		}
	}
	return ''
}

function Write-ClaudeFile {
	# Never lose an existing file: back it up before overwriting.
	param([string] $Path, [string] $Content)

	if (Test-Path -LiteralPath $Path) {
		$Backup = '{0}.bak-{1}' -f $Path, (Get-Date -Format 'yyyyMMdd-HHmmss')
		Copy-Item -LiteralPath $Path -Destination $Backup
		Write-Host "  backed up -> $Backup" -ForegroundColor Yellow
	}
	Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
	Write-Host "  wrote     $Path" -ForegroundColor Green
}

function Initialize-ClaudeThings {
	[CmdletBinding()]
	param(
		[string] $Root = $global:ClaudeThingsRoot,
		[string] $Archive = $global:ClaudeThingsArchive
	)

	$ErrorActionPreference = 'Stop'

	$Meta = Join-Path $Root 'claudthings-setup'
	$Skills = Join-Path $HOME '.claude\skills'

	Write-Host ''
	Write-Host "Setting up claudthings under $Root" -ForegroundColor Cyan

	foreach ($Directory in @($Root, $Archive, $Skills, $Meta)) {
		if (Test-Path -LiteralPath $Directory) {
			Write-Host "  exists    $Directory" -ForegroundColor DarkGray
		}
		else {
			New-Item -ItemType Directory -Path $Directory -Force | Out-Null
			Write-Host "  created   $Directory" -ForegroundColor Green
		}
	}

	$SkillsRegistry = @'
# claudthings skills - master index

Reusable Claude Code **personal skills** distilled from lessons learned across
your claudthings projects. They live in `~/.claude/skills/<name>/SKILL.md` and are
auto-available in EVERY Claude session/project (no install step). This file is the
registry: which skill exists, what it's for, and which project it came from.

## How this works
- A skill = a folder `~/.claude/skills/<name>/` with a `SKILL.md` (YAML frontmatter
  `name` + `description`, then markdown body).
- Claude Code auto-discovers skills from `~/.claude/skills/` every session (create a
  folder = live next session; remove it = gone). Only the `description` is loaded
  into context - it's the trigger; the body loads on demand.
- This registry is MANUAL - it does not auto-update. Keep it in sync by hand.
- Distillation rule: keep the reusable METHOD; genericize/drop one-off environment
  specifics (real hostnames, IPs, one server's settings).

## Skills

| Skill (`~/.claude/skills/...`) | Source project | What it covers |
|---|---|---|
| _(none yet - add a row per skill you create)_ | | |

## Staying in sync
Run `Test-ClaudeSkills` (or press `s` in the `cld` launcher menu). It is read-only:
it flags skills on disk missing from this table and vice-versa, and reports whether
each skill's source project is live, archived, or gone.

## How to make a skill
In any Claude Code session, after solving something reusable, say
"make a skill out of this" - Claude writes `~/.claude/skills/<name>/SKILL.md`. Then
add a row above. To update an existing skill later: "distill lessons into the skill".
'@
	Write-ClaudeFile -Path (Join-Path $Meta 'SKILLS.md') -Content $SkillsRegistry

	$MetaClaudeMd = @"
# claudthings-setup project

The "meta" project that owns the claudthings system: the per-project self-contained
conventions and the skills registry.

## File location rules
- Write every project file INSIDE this folder: ``$Meta``.
- NEVER read or write project files in the home dir.
  Archived/old work lives in claudoldignore - do not use it.
- When memory or notes reference a file by bare name, it lives in THIS folder.

## Key files
- ``SKILLS.md`` - registry of your personal skills (in ~/.claude/skills/).

## The launcher
There is no launcher script. The picker lives in the PowerShell profile itself
(```$PROFILE``) as ``Invoke-ClaudePicker``, aliased ``cld``. Companion commands:
``Test-ClaudeSkills`` (read-only skills reconciliation), ``Initialize-ClaudeThings``
(lay these folders down on a new machine) and ``Sync-Profile`` (deploy the profile
to every host on this machine).
"@
	Write-ClaudeFile -Path (Join-Path $Meta 'CLAUDE.md') -Content $MetaClaudeMd

	Write-Host ''
	Write-Host "Done. Run 'cld' and press 'n' to make your first project." -ForegroundColor Green
	Write-Host ''
}

function Test-ClaudeSkills {
	<#
	.SYNOPSIS
	 READ-ONLY reconciliation of the claudthings skills system. Changes nothing.
	.DESCRIPTION
	 Cross-checks skills on disk (~/.claude/skills/*/SKILL.md) against the SKILLS.md
	 registry, and reports whether each registered skill's source project is live,
	 archived, or gone.
	#>
	[CmdletBinding()]
	param(
		[string] $SkillsDir = (Join-Path $HOME '.claude\skills'),
		[string] $Registry = (Join-Path $global:ClaudeThingsRoot 'claudthings-setup\SKILLS.md'),
		[string] $Root = $global:ClaudeThingsRoot,
		[string] $Archive = $global:ClaudeThingsArchive
	)

	$ErrorActionPreference = 'Stop'
	$Rule = { Write-Host ('-' * 70) -ForegroundColor DarkGray }
	$Issues = 0

	Write-Host ''
	Write-Host ' CHECK-SKILLS  (read-only reconciliation)' -ForegroundColor Cyan
	& $Rule

	$OnDisk = @()
	if (Test-Path -LiteralPath $SkillsDir) {
		$OnDisk = @(Get-ChildItem -LiteralPath $SkillsDir -Directory -ErrorAction SilentlyContinue |
			Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
			Select-Object -ExpandProperty Name | Sort-Object)
	}
	else {
		Write-Host "  Skills dir not found: $SkillsDir" -ForegroundColor Yellow
	}
	Write-Host ("  Skills on disk      : {0}" -f $OnDisk.Count) -ForegroundColor Gray

	$Registered = @{}
	if (Test-Path -LiteralPath $Registry) {
		foreach ($Line in (Get-Content -LiteralPath $Registry)) {
			if ($Line -notmatch '^\s*\|\s*`') { continue }
			$Cells = $Line -split '\|'
			if ($Cells.Count -lt 3) { continue }
			$NameMatch = [regex]::Match($Cells[1], '`([^`]+)`')
			if (-not $NameMatch.Success) { continue }
			$Skill = $NameMatch.Groups[1].Value.Trim()
			$Sources = @([regex]::Matches($Cells[2], '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value.Trim() })
			$Registered[$Skill] = $Sources
		}
	}
	else {
		Write-Host "  Registry not found: $Registry" -ForegroundColor Yellow
	}
	Write-Host ("  Skills in SKILLS.md : {0}" -f $Registered.Count) -ForegroundColor Gray
	& $Rule

	$Unregistered = @($OnDisk | Where-Object { -not $Registered.ContainsKey($_) })
	if ($Unregistered.Count) {
		$Issues += $Unregistered.Count
		Write-Host '  [!] On disk but NOT in SKILLS.md (add a registry row):' -ForegroundColor Yellow
		$Unregistered | ForEach-Object { Write-Host "        $_" -ForegroundColor Yellow }
	}
	else {
		Write-Host '  [ok] Every on-disk skill is registered.' -ForegroundColor Green
	}

	$Missing = @($Registered.Keys | Where-Object { $_ -notin $OnDisk } | Sort-Object)
	if ($Missing.Count) {
		$Issues += $Missing.Count
		Write-Host '  [!] In SKILLS.md but NOT on disk (stale row - skill archived/deleted?):' -ForegroundColor Yellow
		$Missing | ForEach-Object { Write-Host "        $_" -ForegroundColor Yellow }
	}
	else {
		Write-Host '  [ok] Every registered skill exists on disk.' -ForegroundColor Green
	}
	& $Rule

	Write-Host '  Source-project status (skill is self-contained; this is source-of-record only):' -ForegroundColor Cyan
	$SourceIssues = 0
	foreach ($Skill in ($Registered.Keys | Sort-Object)) {
		foreach ($Source in $Registered[$Skill]) {
			if ($Source -match '\s') { continue }
			if (Test-Path -LiteralPath (Join-Path $Root $Source)) { continue }   # live - healthy
			$SourceIssues++
			if (Test-Path -LiteralPath (Join-Path $Archive $Source)) {
				Write-Host ("        [archived] {0}  <- source '{1}' is in claudoldignore" -f $Skill, $Source) -ForegroundColor DarkYellow
			}
			else {
				Write-Host ("        [GONE]     {0}  <- source '{1}' not found live or archived" -f $Skill, $Source) -ForegroundColor Red
			}
		}
	}
	if ($SourceIssues -eq 0) {
		Write-Host '        [ok] All source projects are live in claudthings.' -ForegroundColor Green
	}
	$Issues += $SourceIssues
	& $Rule

	if ($Issues -eq 0) {
		Write-Host '  VERDICT: in sync - nothing to reconcile.' -ForegroundColor Green
	}
	else {
		Write-Host ('  VERDICT: {0} item(s) to review above. Nothing was changed.' -f $Issues) -ForegroundColor Yellow
	}
	Write-Host ''
}

function Invoke-ClaudePicker {
	<#
	.SYNOPSIS
	 Pick a claudthings project, cd into it, and start Claude Code there.
	.PARAMETER Yolo
	 Launch with --dangerously-skip-permissions. Opt-in on purpose: the original
	 launcher did this for every project unconditionally.
	#>
	[CmdletBinding()]
	param(
		[switch] $Yolo,
		[string] $Root = $global:ClaudeThingsRoot,
		[string] $Archive = $global:ClaudeThingsArchive
	)

	$ErrorActionPreference = 'Stop'   # function-scoped; never leaks into the session

	$Claude = Get-ClaudeCommand
	if (-not $Claude) { return }

	if (-not (Test-ProfileInteractive)) {
		Write-Host 'Invoke-ClaudePicker needs an interactive console - it prompts for input.' -ForegroundColor Yellow
		return
	}

	if (-not (Test-Path -LiteralPath $Root)) {
		Write-Host "claudthings root not found: $Root" -ForegroundColor Yellow
		if ((Read-Host 'Create it now? (Y/n)') -match '^[nN]') { return }
		Initialize-ClaudeThings -Root $Root -Archive $Archive
	}

	# Refresh skills before the menu, so the 's' reconciliation sees current state
	# and any session launched from here has the latest skills. Never fatal.
	try { Sync-ClaudeSkills } catch { Write-Host "Skills sync failed - $($_.Exception.Message)" -ForegroundColor Yellow }

	# Remember the last project opened so we can mark it (*) and let Enter re-open it.
	$LastFile = Join-Path $Root '.last'
	$LastName = ''
	if (Test-Path -LiteralPath $LastFile) {
		$Raw = Get-Content -LiteralPath $LastFile -TotalCount 1 -ErrorAction SilentlyContinue
		if ($Raw) { $LastName = ([string]$Raw).Trim() }
	}

	# Loop so menu-only actions (archive/restore/open/dupe/info/skills/filter) return to the menu.
	$TabName = $null
	$Filter = ''
	while ($null -eq $TabName) {
		# Read the project list LIVE each pass. Skip dot-folders (e.g. .claude).
		$AllProjects = @(Get-ChildItem -LiteralPath $Root -Directory |
			Where-Object { $_.Name -notlike '.*' } | Sort-Object Name)
		if ([string]::IsNullOrWhiteSpace($Filter)) { $Projects = $AllProjects }
		else { $Projects = @($AllProjects | Where-Object { $_.Name -like "*$Filter*" }) }

		$NameWidth = 0
		foreach ($Project in $Projects) {
			if ($Project.Name.Length -gt $NameWidth) { $NameWidth = $Project.Name.Length }
		}

		Write-Host ''
		if ([string]::IsNullOrWhiteSpace($Filter)) {
			Write-Host "Claude projects in $Root" -ForegroundColor Cyan
		}
		else {
			Write-Host ("Claude projects in $Root  (filter: '{0}' - type 'c' to clear)" -f $Filter) -ForegroundColor Cyan
		}
		if ($Yolo) { Write-Host '  permissions: BYPASSED (-Yolo)' -ForegroundColor Red }
		else { Write-Host '  permissions: normal prompts' -ForegroundColor DarkGray }

		for ($i = 0; $i -lt $Projects.Count; $i++) {
			$Mark = if ($Projects[$i].Name -eq $LastName) { '*' } else { ' ' }
			$Description = Get-ClaudeProjectDescription $Projects[$i].FullName
			if ([string]::IsNullOrWhiteSpace($Description)) {
				Write-Host ("  {0,2}.{1} {2}" -f ($i + 1), $Mark, $Projects[$i].Name)
			}
			else {
				Write-Host ("  {0,2}.{1} {2}   " -f ($i + 1), $Mark, $Projects[$i].Name.PadRight($NameWidth)) -NoNewline
				Write-Host $Description -ForegroundColor DarkGray
			}
		}
		if ($Projects.Count -eq 0) { Write-Host '  (no projects match this filter)' -ForegroundColor Yellow }

		Write-Host '  n. (new project - create a new subfolder)'
		Write-Host '  o. (open a project in Explorer / VS Code instead of Claude)'
		Write-Host '  d. (duplicate/clone a project as a template)'
		Write-Host '  i. (show info about a project)'
		Write-Host '  r. (remove/archive a project -> claudoldignore)'
		Write-Host '  u. (un-archive/restore a project <- claudoldignore)'
		Write-Host '  s. (check skills - reconcile ~/.claude/skills vs SKILLS.md)'
		Write-Host '  q. (quit - do not launch anything)'
		Write-Host '  0. (none - just open claudthings root)'
		Write-Host '  (or type part of a name to filter)'
		Write-Host ''

		$Question = 'Pick a project number, letter, or filter text'
		if ($LastName -and ($AllProjects.Name -contains $LastName)) {
			$Question = "Pick a project number, letter, or filter text (Enter = $LastName)"
		}
		$Choice = Read-Host $Question

		if ($Choice -eq '0') {
			Set-Location -LiteralPath $Root
			$TabName = 'claudthings'
		}
		elseif ($Choice -match '^[qQ]$') {
			Write-Host 'Cancelled - nothing launched.' -ForegroundColor DarkGray
			return
		}
		elseif ([string]::IsNullOrWhiteSpace($Choice)) {
			# Enter with no input re-opens the last-used project, if it still exists.
			if ($LastName -and ($AllProjects.Name -contains $LastName)) {
				$Target = ($AllProjects | Where-Object { $_.Name -eq $LastName })[0].FullName
				Set-Location -LiteralPath $Target
				$TabName = $LastName
				Write-Host "-> $Target" -ForegroundColor Green
			}
			else {
				Write-Host 'No last-used project to open. Pick a number.' -ForegroundColor Yellow
			}
		}
		elseif ($Choice -match '^[nN]$') {
			$NewName = ''
			while ([string]::IsNullOrWhiteSpace($NewName)) {
				# Sanitize: keep letters/digits/dash/underscore/dot, collapse anything else to a dash.
				$NewName = ((Read-Host 'New project name') -replace '[^A-Za-z0-9._-]+', '-').Trim('-')
				if ([string]::IsNullOrWhiteSpace($NewName)) {
					Write-Host "Name can't be empty. Try again." -ForegroundColor Yellow
				}
			}
			$Target = Join-Path $Root $NewName
			if (Test-Path -LiteralPath $Target) {
				Write-Host "Project '$NewName' already exists - opening it." -ForegroundColor Yellow
			}
			else {
				New-Item -ItemType Directory -Path $Target | Out-Null
				# Seed a CLAUDE.md so the new project is self-contained from the first session.
				$Seed = @"
# $NewName project

This is a self-contained project folder. Keep ALL project files here.

## File location rules
- Write every project file INSIDE this folder: ``$Target``.
  That includes notes, todos, documentation, scripts, and any output files.
- NEVER read or write project files in the home dir.
  Archived/old work lives in claudoldignore - do not use it.
- When memory or notes reference a file by bare name, it lives in THIS folder. Read it from here.
"@
				Set-Content -LiteralPath (Join-Path $Target 'CLAUDE.md') -Value $Seed -Encoding utf8
				Write-Host "Created new project: $Target (with CLAUDE.md)" -ForegroundColor Green
			}
			Set-Location -LiteralPath $Target
			$TabName = $NewName
		}
		elseif ($Choice -match '^[oO]$') {
			# Open in Explorer or VS Code instead of launching Claude. Returns to the menu.
			if ($Projects.Count -eq 0) { Write-Host 'No projects to open.' -ForegroundColor Yellow }
			else {
				$Pick = Read-Host 'Open which project number (blank to cancel)'
				if ($Pick -match '^\d+$' -and [int]$Pick -ge 1 -and [int]$Pick -le $Projects.Count) {
					$Directory = $Projects[[int]$Pick - 1].FullName
					if ((Read-Host 'Open in (e)xplorer or (v)s code? [e]') -match '^[vV]') {
						if (Get-Command code -ErrorAction SilentlyContinue) {
							& code $Directory
							Write-Host "Opened in VS Code: $Directory" -ForegroundColor Green
						}
						else {
							Write-Host "Could not launch 'code' - is VS Code on PATH?" -ForegroundColor Red
						}
					}
					else {
						Invoke-Item -LiteralPath $Directory
						Write-Host "Opened in Explorer: $Directory" -ForegroundColor Green
					}
				}
				elseif ($Pick -ne '') { Write-Host 'Invalid selection.' -ForegroundColor Yellow }
			}
		}
		elseif ($Choice -match '^[dD]$') {
			# Duplicate a project (minus its .claude session state) as a template.
			if ($Projects.Count -eq 0) { Write-Host 'No projects to duplicate.' -ForegroundColor Yellow }
			else {
				$Pick = Read-Host 'Duplicate which project number (blank to cancel)'
				if ($Pick -match '^\d+$' -and [int]$Pick -ge 1 -and [int]$Pick -le $Projects.Count) {
					$SourceProject = $Projects[[int]$Pick - 1]
					$NewName = ''
					while ([string]::IsNullOrWhiteSpace($NewName)) {
						$NewName = ((Read-Host 'Name for the copy') -replace '[^A-Za-z0-9._-]+', '-').Trim('-')
						if ([string]::IsNullOrWhiteSpace($NewName)) {
							Write-Host "Name can't be empty. Try again." -ForegroundColor Yellow
						}
					}
					$Destination = Join-Path $Root $NewName
					if (Test-Path -LiteralPath $Destination) {
						Write-Host "'$NewName' already exists. Nothing copied." -ForegroundColor Yellow
					}
					else {
						New-Item -ItemType Directory -Path $Destination | Out-Null
						Get-ChildItem -LiteralPath $SourceProject.FullName -Force |
							Where-Object { $_.Name -ne '.claude' } |
							ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force }
						Write-Host "Cloned '$($SourceProject.Name)' -> $Destination (without .claude)" -ForegroundColor Green
					}
				}
				elseif ($Pick -ne '') { Write-Host 'Invalid selection.' -ForegroundColor Yellow }
			}
		}
		elseif ($Choice -match '^[iI]$') {
			if ($Projects.Count -eq 0) { Write-Host 'No projects to inspect.' -ForegroundColor Yellow }
			else {
				$Pick = Read-Host 'Info for which project number (blank to cancel)'
				if ($Pick -match '^\d+$' -and [int]$Pick -ge 1 -and [int]$Pick -le $Projects.Count) {
					$Project = $Projects[[int]$Pick - 1]
					$Files = @(Get-ChildItem -LiteralPath $Project.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
					$Newest = $Files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
					$Modified = if ($Newest) { $Newest.LastWriteTime } else { $Project.LastWriteTime }
					Write-Host ''
					Write-Host ("  {0}" -f $Project.Name) -ForegroundColor Cyan
					Write-Host ("    path         : {0}" -f $Project.FullName)
					Write-Host ("    files        : {0}" -f $Files.Count)
					Write-Host ("    last modified: {0}" -f $Modified.ToString('yyyy-MM-dd HH:mm'))
					Write-Host ("    CLAUDE.md    : {0}" -f
						$(if (Test-Path -LiteralPath (Join-Path $Project.FullName 'CLAUDE.md')) { 'yes' } else { 'no' }))
				}
				elseif ($Pick -ne '') { Write-Host 'Invalid selection.' -ForegroundColor Yellow }
			}
		}
		elseif ($Choice -match '^[rR]$') {
			# Archive (move, never delete) into claudoldignore, then re-show the menu.
			if ($Projects.Count -eq 0) { Write-Host 'No projects to remove.' -ForegroundColor Yellow }
			else {
				$Pick = Read-Host 'Remove which project number (blank to cancel)'
				if ($Pick -match '^\d+$' -and [int]$Pick -ge 1 -and [int]$Pick -le $Projects.Count) {
					$Victim = $Projects[[int]$Pick - 1]
					if ((Read-Host "Move '$($Victim.Name)' to claudoldignore? (y/N)") -match '^[yY]') {
						if (-not (Test-Path -LiteralPath $Archive)) {
							New-Item -ItemType Directory -Path $Archive -Force | Out-Null
						}
						$Destination = Join-Path $Archive $Victim.Name
						if (Test-Path -LiteralPath $Destination) {
							$Destination = '{0}.removed-{1}' -f $Destination, (Get-Date -Format 'yyyyMMdd-HHmmss')
						}
						try {
							Move-Item -LiteralPath $Victim.FullName -Destination $Destination -ErrorAction Stop
							Write-Host "Archived to: $Destination" -ForegroundColor Green
						}
						catch {
							Write-Host "Could not move '$($Victim.Name)' - it's in use by another process." -ForegroundColor Red
							Write-Host 'Close any terminal tab / editor / Claude session in that folder, then retry.' -ForegroundColor Yellow
						}
					}
					else { Write-Host 'Cancelled.' -ForegroundColor Yellow }
				}
				elseif ($Pick -ne '') { Write-Host 'Invalid selection. Nothing removed.' -ForegroundColor Yellow }
			}
		}
		elseif ($Choice -match '^[uU]$') {
			$Archived = @()
			if (Test-Path -LiteralPath $Archive) {
				$Archived = @(Get-ChildItem -LiteralPath $Archive -Directory |
					Where-Object { $_.Name -notlike '.*' } | Sort-Object Name)
			}
			if ($Archived.Count -eq 0) { Write-Host "Nothing archived in $Archive." -ForegroundColor Yellow }
			else {
				Write-Host ''
				Write-Host "Archived projects in $Archive" -ForegroundColor Cyan
				for ($i = 0; $i -lt $Archived.Count; $i++) {
					Write-Host ("  {0}. {1}" -f ($i + 1), $Archived[$i].Name)
				}
				$Pick = Read-Host 'Restore which project number (blank to cancel)'
				if ($Pick -match '^\d+$' -and [int]$Pick -ge 1 -and [int]$Pick -le $Archived.Count) {
					$Revive = $Archived[[int]$Pick - 1]
					$Destination = Join-Path $Root $Revive.Name
					if (Test-Path -LiteralPath $Destination) {
						$Destination = '{0}.restored-{1}' -f $Destination, (Get-Date -Format 'yyyyMMdd-HHmmss')
					}
					try {
						Move-Item -LiteralPath $Revive.FullName -Destination $Destination -ErrorAction Stop
						Write-Host "Restored to: $Destination" -ForegroundColor Green
					}
					catch {
						Write-Host "Could not move '$($Revive.Name)' - it's in use by another process." -ForegroundColor Red
					}
				}
				elseif ($Pick -ne '') { Write-Host 'Invalid selection. Nothing restored.' -ForegroundColor Yellow }
			}
		}
		elseif ($Choice -match '^[sS]$') {
			Test-ClaudeSkills -Root $Root -Archive $Archive
			Write-Host '(press Enter to return to the menu)' -ForegroundColor DarkGray
			[void](Read-Host)
		}
		elseif ($Choice -match '^[cC]$') {
			$Filter = ''
		}
		elseif ($Choice -match '^\d+$' -and [int]$Choice -ge 1 -and [int]$Choice -le $Projects.Count) {
			$Target = $Projects[[int]$Choice - 1].FullName
			Set-Location -LiteralPath $Target
			$TabName = $Projects[[int]$Choice - 1].Name
			Write-Host "-> $Target" -ForegroundColor Green
		}
		else {
			# Anything else non-empty is type-to-filter text. A single hit opens directly.
			$Hits = @($AllProjects | Where-Object { $_.Name -like "*$Choice*" })
			if ($Hits.Count -eq 1) {
				Set-Location -LiteralPath $Hits[0].FullName
				$TabName = $Hits[0].Name
				Write-Host "-> $($Hits[0].FullName)" -ForegroundColor Green
			}
			elseif ($Hits.Count -gt 1) { $Filter = $Choice }
			else { Write-Host "No projects match '$Choice'. Try again." -ForegroundColor Yellow }
		}
	}

	# Record the opened project (skip the root pseudo-target) as last-used. Best effort.
	if ($TabName -and $TabName -ne 'claudthings') {
		try { Set-Content -LiteralPath $LastFile -Value $TabName -Encoding utf8 } catch { }
	}

	# Every project folder is its own untrusted directory, so without this you meet the
	# workspace-trust dialog once per project. Best effort - never block the launch.
	try { Set-ClaudeDirectoryTrust -Path (Get-Location).Path } catch { }

	# Stop Claude Code from overriding the tab title, then pin it. The prompt function
	# honours ProfilePinnedTitle, so the name survives after Claude exits.
	$env:CLAUDE_CODE_DISABLE_TERMINAL_TITLE = '1'
	$global:ProfilePinnedTitle = $TabName
	try { $Host.UI.RawUI.WindowTitle = $TabName } catch { }

	if ($Yolo) {
		Write-Host 'Launching Claude Code with ALL permission prompts bypassed (-Yolo).' -ForegroundColor Red
		& $Claude.Source --dangerously-skip-permissions
	}
	else {
		& $Claude.Source
	}

	Write-Host ("Tab pinned to '{0}'. Run Clear-ProfilePinnedTitle to restore the normal title." -f $TabName) -ForegroundColor DarkGray
}

Set-Alias -Name cld -Value Invoke-ClaudePicker -Force

#endregion

#region Deployment ------------------------------------------------------------

function Sync-Profile {
	<#
	.SYNOPSIS
	 Copy this profile to every profile location on this machine.
	.DESCRIPTION
	 Replaces Sync-DfProfileScript, which lived in the DupreeFunctions module and so
	 was unavailable on any machine without it. Deploys the console, ISE and VS Code
	 profile names into both the PowerShell 7 and Windows PowerShell folders, so
	 running it from either host updates all of them.
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param([string] $Source)

	$ErrorActionPreference = 'Stop'

	if (-not $Source) {
		# Prefer the repo copy when this machine has one, so syncing from a deployed
		# profile still publishes the version that is under source control.
		$Candidates = @()
		if ($env:githome) {
			$Candidates += Join-Path $env:githome 'PowerShell\Profile\Microsoft.PowerShell_profile.ps1'
		}
		$Candidates += $global:ProfileSourcePath
		$Source = $Candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
	}
	if (-not $Source) {
		Write-Host 'Could not work out which file to deploy. Pass -Source explicitly.' -ForegroundColor Red
		return
	}
	Write-Host "Source: $Source" -ForegroundColor Cyan

	# GetFolderPath, not "$HOME\Documents": OneDrive redirection is common on work
	# machines, and a hardcoded path silently writes profiles nobody ever loads.
	$Documents = [System.Environment]::GetFolderPath('MyDocuments')
	$OnWindows = if ($null -ne $PSVersionTable.Platform) { $PSVersionTable.Platform -eq 'Win32NT' } else { $true }

	$Directories = New-Object System.Collections.Generic.List[string]
	if ($Documents) {
		$Directories.Add((Join-Path $Documents 'PowerShell'))
		if ($OnWindows) { $Directories.Add((Join-Path $Documents 'WindowsPowerShell')) }
	}
	# Whatever this host actually loads, however its Documents folder is arranged.
	$Directories.Add((Split-Path -Parent $PROFILE))

	$Names = 'Microsoft.PowerShell_profile.ps1',
	'Microsoft.PowerShellISE_profile.ps1',
	'Microsoft.VSCode_profile.ps1'

	$Seen = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
	$Copied = 0
	foreach ($Directory in $Directories) {
		if (-not $Seen.Add($Directory)) { continue }
		if (-not (Test-Path -LiteralPath $Directory)) {
			New-Item -ItemType Directory -Path $Directory -Force | Out-Null
		}
		foreach ($Name in $Names) {
			$Destination = Join-Path $Directory $Name
			# Always copy from $Source. Chaining copies off $PROFILE means one failed
			# copy quietly propagates a stale profile to the other hosts.
			if ($PSCmdlet.ShouldProcess($Destination, 'Deploy profile')) {
				try {
					Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
					Write-Host "  copied  $Destination" -ForegroundColor Green
					$Copied++
				}
				catch {
					Write-Host "  FAILED  $Destination - $($_.Exception.Message)" -ForegroundColor Red
				}
			}
		}
	}
	Write-Host ("Deployed to {0} location(s)." -f $Copied) -ForegroundColor Cyan
}

#endregion

Write-ProfileStatus 'Ready' ('{0:N0} ms' -f $ProfileTimer.Elapsed.TotalMilliseconds) DarkGray
if (-not $ProfileQuiet) { Write-Host '' }
