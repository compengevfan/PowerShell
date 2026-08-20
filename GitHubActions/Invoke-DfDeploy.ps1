<#
.SYNOPSIS
    Deploys DupreeFunctions to every machine listed in deploy-targets.json.

.DESCRIPTION
    Runs on the self hosted Linux runner. Connects to each target over PowerShell SSH
    remoting, which reaches Windows and Linux identically, and runs Install-DfModule.ps1
    there. Each target refreshes its own git clone, so nothing is copied over the wire
    except the installer script itself.

    A failure on one host does not stop the others. The script reports every host and
    exits non zero if any of them failed.

.PARAMETER TargetsFile
    Inventory of machines to deploy to. Defaults to deploy-targets.json beside this script.

.PARAMETER PrivateKey
    Contents of the deploy private key. Defaults to the DF_DEPLOY_SSH_KEY environment
    variable, which the workflow populates from the repository secret.

.EXAMPLE
    ./Invoke-DfDeploy.ps1
#>
[CmdletBinding()]
Param(
    [string] $TargetsFile = (Join-Path $PSScriptRoot "deploy-targets.json"),
    [string] $PrivateKey = $env:DF_DEPLOY_SSH_KEY,
    [string] $Branch = "master"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $TargetsFile)) { throw "Targets file not found at $TargetsFile" }
if ([string]::IsNullOrWhiteSpace($PrivateKey)) {
    throw "No deploy private key supplied. Set the DF_DEPLOY_SSH_KEY secret or pass -PrivateKey."
}

$Inventory = Get-Content $TargetsFile -Raw | ConvertFrom-Json
$DefaultUser = if ($Inventory.defaultUser) { $Inventory.defaultUser } else { "dfdeploy" }

$Targets = @($Inventory.targets | Where-Object { $_.host })
if ($Targets.Count -eq 0) { throw "No targets with a host defined in $TargetsFile" }

$InstallScript = Join-Path $PSScriptRoot "Install-DfModule.ps1"
if (!(Test-Path $InstallScript)) { throw "Installer not found at $InstallScript" }

#Everything transient lives here so the key never lands in the workspace
$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) "df-deploy-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

try {
    $KeyFile = Join-Path $WorkDir "deploy_key"
    #WriteAllText rather than Out-File so no BOM is added, ssh rejects a key with one.
    #Carriage returns are stripped because a key pasted into the secret from Windows
    #carries CRLF, which ssh rejects with a misleading libcrypto error.
    $Normalised = $PrivateKey.Replace("`r", "").TrimEnd() + "`n"
    [System.IO.File]::WriteAllText($KeyFile, $Normalised)
    chmod 600 $KeyFile
    if ($LASTEXITCODE -ne 0) { throw "Failed to set permissions on the temporary key file" }

    #Fail with something readable if the secret is not actually a usable private key
    $null = ssh-keygen -y -f $KeyFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "DF_DEPLOY_SSH_KEY is not a valid private key. Paste the whole file, including the BEGIN and END lines."
    }

    #Collect host keys up front so ssh does not stall on an interactive prompt
    $KnownHosts = Join-Path $WorkDir "known_hosts"
    Write-Host "Scanning host keys for $($Targets.Count) target(s)"
    foreach ($Target in $Targets) {
        $Scanned = ssh-keyscan -H $Target.host 2>$null
        if ($Scanned) { Add-Content -Path $KnownHosts -Value $Scanned }
        else { Write-Host "  WARNING: no host key returned by $($Target.host)" }
    }
    if (!(Test-Path $KnownHosts)) { New-Item -ItemType File -Path $KnownHosts -Force | Out-Null }

    $Results = foreach ($Target in $Targets) {
        $TargetHost = $Target.host
        $TargetUser = if ($Target.user) { $Target.user } else { $DefaultUser }

        Write-Host ""
        Write-Host "=== $TargetHost (as $TargetUser) ==="

        try {
            Invoke-Command -HostName $TargetHost -UserName $TargetUser -KeyFilePath $KeyFile `
                -Options @{ UserKnownHostsFile = $KnownHosts } `
                -FilePath $InstallScript -ArgumentList @("https://github.com/compengevfan/PowerShell.git", $Branch)

            [PSCustomObject]@{ Host = $TargetHost; Status = "Succeeded"; Detail = "" }
        }
        catch {
            Write-Host "FAILED: $($_.Exception.Message)"
            [PSCustomObject]@{ Host = $TargetHost; Status = "Failed"; Detail = $_.Exception.Message }
        }
    }
}
finally {
    Remove-Item $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Deployment summary ==="
$Results | Format-Table Host, Status -AutoSize | Out-String | Write-Host

$Failed = @($Results | Where-Object { $_.Status -eq "Failed" })
if ($Failed.Count -gt 0) {
    throw "$($Failed.Count) of $($Results.Count) target(s) failed: $($Failed.Host -join ', ')"
}

Write-Host "All $($Results.Count) target(s) updated successfully."
