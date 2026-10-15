<#PSScriptInfo

.VERSION 5.0.0

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
5.0.0 Removed the claudthings launcher entirely: no Invoke-ClaudePicker / cld, no
      Initialize-ClaudeThings, no Test-ClaudeSkills, no ~\claudthings paths, and
      no pinned window title. Sync-ClaudeSkills survives as a standalone command
      (run it yourself; nothing calls it automatically) and so does
      Set-ClaudeDirectoryTrust. The banner still reports the Claude Code version.

4.6.0 Dropped VMware entirely: no PowerCLI banner line, and the prompt no longer
      reads $global:DefaultVIServers, so there is no connected-vCenter segment in
      the prompt or the window title.

4.5.0 Sync-ClaudeSkills pulls $giteahome\skills and mirrors it into
      ~\.claude\skills. Mirror means a skill removed from the repo is removed
      locally. Skipped entirely when $env:giteahome is not set, and the pull is
      bounded so an unreachable Gitea cannot hang the shell.

4.4.0 A default shell now opens in $githome, so Claude Code starts in a directory
      it already trusts. Deliberate working directories (Open PowerShell here, a
      VS Code workspace, a configured startingDirectory) are left alone.
      Set-ClaudeDirectoryTrust pre-accepts the workspace-trust dialog for a
      directory. PowerShell 7+ only.

4.3.0 All four home paths now report identically: Git, Gitea, Dropbox and Proton
      each say so when their environment variable is empty.

4.2.0 Banner reports Proton home from $env:protonhome, quiet when unset like
      Dropbox home.

4.1.0 Banner reports Gitea home from $env:giteahome, alongside Git home.

4.0.0 Self-contained: this one file is the whole setup, so copying it to a new
      machine is the entire install. Deployment no longer needs DupreeFunctions
      (Sync-Profile replaces Sync-DfProfileScript and finds its own source).

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
	Write-ProfileStatus 'Claude Code' $ClaudeVersion Green
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

	$Branch = if ($IsFileSystem) { Get-PromptGitBranch -Path $FullPath } else { $null }

	$Title = '{0}{1} {2}' -f $env:USERNAME, $(if ($global:ProfileIsAdmin) { ' (Admin)' }), $FullPath
	try { $Host.UI.RawUI.WindowTitle = $Title } catch { }

	$Line = New-Object System.Text.StringBuilder
	[void]$Line.Append($Ansi.Dim).Append($env:USERNAME)
	if ($global:ProfileIsAdmin) { [void]$Line.Append($Ansi.Red).Append('#') }
	[void]$Line.Append(' ').Append($Ansi.Yellow).Append($ShortPath)
	if ($Branch) { [void]$Line.Append(' ').Append($Ansi.Cyan).Append('(').Append($Branch).Append(')') }
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

# Two conveniences for Claude Code, and nothing else: keep ~\.claude\skills in
# step with the Gitea skills repo, and pre-accept the workspace-trust dialog for
# a directory. Nothing here runs at load time - these are definitions only, so
# call them when you want them.

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
		# A pull against an unreachable host would otherwise hang the shell for
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

	# A skill is a folder with a SKILL.md. This is why the repo's root README.md
	# is not copied: it is not a skill.
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
