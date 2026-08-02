<#PSScriptInfo

.VERSION 3.0.0

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
 the ISE and VS Code; Sync-DfProfileScript copies it to all of them.

#>
Param()

$ProfileTimer = [System.Diagnostics.Stopwatch]::StartNew()
$ProfileQuiet = [bool]$env:PSPROFILE_QUIET

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

# Sync-DfProfileScript reads $githome, so keep these as variables, not just env vars.
$global:githome = $env:githome
if ($githome) { Write-ProfileStatus 'Git home' $githome Green }
else { Write-ProfileStatus 'Git home' 'not set - $env:githome is empty' Yellow }

$global:dropboxhome = $env:dropboxhome
if ($dropboxhome) { Write-ProfileStatus 'Dropbox home' $dropboxhome Green }

$PowerCLI = Get-Module -ListAvailable VMware.Vim | Sort-Object Version -Descending | Select-Object -First 1
if ($PowerCLI) { Write-ProfileStatus 'PowerCLI' ('{0}.{1}' -f $PowerCLI.Version.Major, $PowerCLI.Version.Minor) Green }
else { Write-ProfileStatus 'PowerCLI' 'not installed' Yellow }

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

	$Title = '{0}{1} {2}' -f $env:USERNAME, $(if ($global:ProfileIsAdmin) { ' (Admin)' }), $FullPath
	if ($vCenter) { $Title += " - $vCenter" }
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

Write-ProfileStatus 'Ready' ('{0:N0} ms' -f $ProfileTimer.Elapsed.TotalMilliseconds) DarkGray
if (-not $ProfileQuiet) { Write-Host '' }
