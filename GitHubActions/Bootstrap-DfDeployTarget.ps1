<#
.SYNOPSIS
    One time preparation of a machine so it can receive DupreeFunctions deployments.

.DESCRIPTION
    Run this once on each new target, elevated. On Windows run it from an elevated
    PowerShell prompt. On Linux run it with sudo pwsh.

    It creates the deploy account, authorises the deploy public key, registers the
    PowerShell SSH subsystem, and pre-creates the directories the deploy account needs
    to own. After this the host can be added to deploy-targets.json.

    It finishes by installing the module once, so a freshly built machine has
    DupreeFunctions immediately rather than waiting for the next merge to master. That
    first install creates the staging clone the upgrade process reuses from then on.

    PowerShell 7 must already be installed. On Linux this script requires pwsh anyway,
    and on Windows the SSH subsystem points at the PowerShell 7 executable.

.PARAMETER SkipInitialInstall
    Prepare the host but do not install the module yet. The machine will have no
    DupreeFunctions until the next deployment reaches it.

.PARAMETER PublicKey
    The deploy public key, ie the contents of the .pub file whose private half is stored
    in the DF_DEPLOY_SSH_KEY repository secret.

.EXAMPLE
    # Windows, elevated
    .\Bootstrap-DfDeployTarget.ps1 -PublicKey "ssh-ed25519 AAAA... df-deploy"

.EXAMPLE
    # Linux
    sudo pwsh ./Bootstrap-DfDeployTarget.ps1 -PublicKey "ssh-ed25519 AAAA... df-deploy"
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [string] $PublicKey,
    [string] $DeployUser = "dfdeploy",
    [switch] $SkipInitialInstall
)

$ErrorActionPreference = "Stop"

#$IsWindows does not exist in Windows PowerShell 5.1, where it is always Windows
$OnWindows = if ($null -eq $IsWindows) { $true } else { $IsWindows }

if ($PublicKey -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-\S+)\s+\S+') {
    throw "PublicKey does not look like an OpenSSH public key. Pass the contents of the .pub file."
}

function Add-SshdConfigLine {
    Param([string] $ConfigPath, [string] $Line, [string] $MatchPattern)

    if (!(Test-Path $ConfigPath)) { throw "sshd config not found at $ConfigPath" }

    $Existing = Get-Content $ConfigPath
    if ($Existing | Where-Object { $_ -match $MatchPattern }) {
        Write-Host "  sshd already has a $MatchPattern line, leaving it alone"
        return $false
    }

    Write-Host "  Adding to $ConfigPath : $Line"
    Add-Content -Path $ConfigPath -Value $Line
    return $true
}

if ($OnWindows) {
    #Refuse to run unelevated, everything below needs administrator
    $Principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run from an elevated PowerShell prompt."
    }

    Write-Host "Installing OpenSSH Server"
    $Capability = Get-WindowsCapability -Online -Name "OpenSSH.Server*"
    if ($Capability.State -ne "Installed") { Add-WindowsCapability -Online -Name $Capability.Name | Out-Null }
    else { Write-Host "  Already installed" }

    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd

    Write-Host "Registering the PowerShell SSH subsystem"
    #The subsystem path cannot contain spaces, so the 8.3 short name is required here
    $PwshShortPath = "c:/progra~1/PowerShell/7/pwsh.exe"
    if (!(Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe")) {
        throw "PowerShell 7 not found at $env:ProgramFiles\PowerShell\7\pwsh.exe. Install it before bootstrapping."
    }
    $SshdConfig = "$env:ProgramData\ssh\sshd_config"
    $SubsystemAdded = Add-SshdConfigLine -ConfigPath $SshdConfig `
        -Line "Subsystem powershell $PwshShortPath -sshs -NoLogo" `
        -MatchPattern '^\s*Subsystem\s+powershell'

    Write-Host "Creating the $DeployUser account"
    $ExistingUser = Get-LocalUser -Name $DeployUser -ErrorAction SilentlyContinue
    if (!$ExistingUser) {
        #Key authentication is the only path in, so the password is random and discarded.
        #Create plus GetBytes rather than RandomNumberGenerator::Fill, which is .NET Core
        #only. Ansible's win_shell runs Windows PowerShell 5.1, where Fill does not exist.
        $RandomBytes = [byte[]]::new(32)
        $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        try { $Rng.GetBytes($RandomBytes) } finally { $Rng.Dispose() }
        $RandomPassword = ConvertTo-SecureString ([Convert]::ToBase64String($RandomBytes)) -AsPlainText -Force

        New-LocalUser -Name $DeployUser -Password $RandomPassword -FullName "DupreeFunctions Deploy" `
            -Description "Service account for DupreeFunctions deployments" -PasswordNeverExpires | Out-Null
    }
    else { Write-Host "  Already exists" }

    #Needed so the SSH session can write to Program Files
    Add-LocalGroupMember -Group "Administrators" -Member $DeployUser -ErrorAction SilentlyContinue

    Write-Host "Authorising the deploy key"
    #Administrator accounts read from this shared file, not from the user profile
    $AuthKeys = "$env:ProgramData\ssh\administrators_authorized_keys"
    if (!(Test-Path $AuthKeys)) { New-Item -ItemType File -Path $AuthKeys -Force | Out-Null }

    if ((Get-Content $AuthKeys -ErrorAction SilentlyContinue) -contains $PublicKey) {
        Write-Host "  Key already authorised"
    }
    else { Add-Content -Path $AuthKeys -Value $PublicKey }

    #sshd rejects this file unless only Administrators and SYSTEM can touch it
    icacls.exe $AuthKeys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to set ACLs on $AuthKeys" }

    Write-Host "Creating directories owned by $DeployUser"
    $Paths = @(
        "$env:ProgramData\DupreeFunctions\repo"
        "$env:ProgramFiles\WindowsPowerShell\Modules\DupreeFunctions"
        "$env:ProgramFiles\PowerShell\Modules\DupreeFunctions"
    )
    foreach ($Path in $Paths) {
        if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        icacls.exe $Path /grant "${DeployUser}:(OI)(CI)M" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to grant $DeployUser rights on $Path" }
        Write-Host "  $Path"
    }

    if ($SubsystemAdded) {
        Write-Host "Restarting sshd to pick up the subsystem"
        Restart-Service sshd
    }
}
else {
    if ([System.Environment]::UserName -ne "root") { throw "This script must be run as root, use sudo pwsh." }

    Write-Host "Creating the $DeployUser account"
    if (!(getent passwd $DeployUser)) {
        #A home directory is required so sshd can read ~/.ssh/authorized_keys
        useradd --system --create-home --shell /bin/bash $DeployUser
        if ($LASTEXITCODE -ne 0) { throw "useradd failed for $DeployUser" }
    }
    else { Write-Host "  Already exists" }

    $DeployHome = (getent passwd $DeployUser).Split(":")[5]
    if (!$DeployHome) { throw "Could not determine the home directory for $DeployUser" }

    Write-Host "Authorising the deploy key"
    $SshDir = Join-Path $DeployHome ".ssh"
    $AuthKeys = Join-Path $SshDir "authorized_keys"
    if (!(Test-Path $SshDir)) { New-Item -ItemType Directory -Path $SshDir -Force | Out-Null }
    if (!(Test-Path $AuthKeys)) { New-Item -ItemType File -Path $AuthKeys -Force | Out-Null }

    if ((Get-Content $AuthKeys -ErrorAction SilentlyContinue) -contains $PublicKey) {
        Write-Host "  Key already authorised"
    }
    else { Add-Content -Path $AuthKeys -Value $PublicKey }

    #sshd ignores the key unless the permissions are tight
    chmod 700 $SshDir
    chmod 600 $AuthKeys
    chown -R "${DeployUser}:${DeployUser}" $SshDir

    Write-Host "Registering the PowerShell SSH subsystem"
    $PwshPath = (Get-Command pwsh).Source
    $SubsystemAdded = Add-SshdConfigLine -ConfigPath "/etc/ssh/sshd_config" `
        -Line "Subsystem powershell $PwshPath -sshs -NoLogo" `
        -MatchPattern '^\s*Subsystem\s+powershell'

    Write-Host "Creating directories owned by $DeployUser"
    #Only the DupreeFunctions folder is handed over, the rest of the module root stays root owned
    $Paths = @(
        "/opt/dupreefunctions/repo"
        "/usr/local/share/powershell/Modules/DupreeFunctions"
    )
    foreach ($Path in $Paths) {
        if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        chown -R "${DeployUser}:${DeployUser}" $Path
        Write-Host "  $Path"
    }

    if ($SubsystemAdded) {
        Write-Host "Restarting sshd to pick up the subsystem"
        systemctl restart sshd 2>$null
        if ($LASTEXITCODE -ne 0) { systemctl restart ssh }
    }
}

if ($SkipInitialInstall) {
    Write-Host ""
    Write-Host "Skipping the initial install. This host has no module until the next deployment."
}
else {
    $Installer = Join-Path $PSScriptRoot "Install-DfModule.ps1"

    if (!(Test-Path $Installer)) {
        Write-Host ""
        Write-Host "WARNING: Install-DfModule.ps1 was not found beside this script, so no module was installed."
        Write-Host "         Run it on this host, or wait for the next deployment."
    }
    else {
        Write-Host ""
        Write-Host "Running the first install"

        try {
            if ($OnWindows) {
                & $Installer

                #Reapply across everything just created, so the deploy account can replace it
                Write-Host "Returning ownership to $DeployUser"
                foreach ($Path in $Paths) {
                    icacls.exe $Path /grant "${DeployUser}:(OI)(CI)M" /T | Out-Null
                }
            }
            else {
                #Run as the deploy account rather than as root. The directories were just
                #handed to $DeployUser, and git refuses to operate on a repository owned by
                #someone else, so a root install would fail on the staging clone. Running as
                #the deploy account also proves it has the permissions a real deployment needs.
                Write-Host "Running as $DeployUser"
                #The login form matters. A plain su keeps the caller's working directory,
                #which is /root when this is driven by Ansible or sudo, and $DeployUser
                #cannot read that. Child processes then fail to even start, with git
                #reporting a permission error against the working directory rather than
                #against anything it was asked to touch.
                su -s /bin/bash - $DeployUser -c "$PwshPath -File `"$Installer`""
                if ($LASTEXITCODE -ne 0) { throw "the installer exited with code $LASTEXITCODE" }
            }
        }
        catch {
            Write-Host ""
            Write-Host "WARNING: the host was prepared successfully but the first install failed:"
            Write-Host "         $($_.Exception.Message)"
            Write-Host "         Fix the cause and rerun Install-DfModule.ps1, or let the next deployment retry."
        }
    }
}

Write-Host ""
Write-Host "$([System.Net.Dns]::GetHostName()) is ready. Add it to GitHubActions/deploy-targets.json to start receiving deployments."
