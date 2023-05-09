[CmdletBinding()]
Param(
)

#Display PowerShell Version
Write-Host "`nPowerShell Version:"
$PSVersionTable.PSVersion

#Check for NuGet and PowerShellGet
$NuGetCheck = Get-PackageProvider | Where-Object {$_.Name -eq "NuGet"}
if ($null -ne $NuGetCheck) {Write-Host "`nNuGet Version $($NuGetCheck.Version) installed." -ForegroundColor green; $NuGetGood = $true}
else {Write-Host "`nNuGet is not installed."-ForegroundColor red; $NuGetGood = $false}

$PowerShellGetCheck = Get-PackageProvider | Where-Object {$_.Name -eq "PowerShellGet"}
if ($null -ne $NuGetCheck) {Write-Host "`nPowerShellGet Version $($PowerShellGetCheck.Version) installed." -ForegroundColor green; $PowerShellGetGood = $true}
else {Write-Host "`nPowerShellGet is not installed." -ForegroundColor red; $PowerShellGetGood = $false}

if ($NuGetGood -and $PowerShellGetGood)
{
    #Check for Profile scripts
    if ($null -eq (Test-Path -Path "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell")) 
    {
        New-Item -Path "$([Environment]::GetFolderPath("MyDocuments"))" -Name "PowerShell" -ItemType "directory"
        Install-Script -Name Microsoft.PowerShell_profile
        Install-Script -Name Microsoft.PowerShellISE_profile
        Install-Script -Name Microsoft.VSCode_profile
        Write-Host "PowerShell Profile Scripts installed. Restart PowerShell for change to take effect." -ForegroundColor Yellow
    }
    else
    {
        #Get Latest Profile Script Version
        $ProfileScriptUpdated = $false
        $LatestProfileScriptVersion = (Find-Script -Name "Microsoft.PowerShell_profile").Version
        $ProfileScripts = Get-ChildItem "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\*" -Include *.ps1
        foreach ($ProfileScript in $ProfileScripts) 
        {
            $ProfileScriptInfo = Test-ScriptFileInfo $ProfileScript -ErrorAction SilentlyContinue
            $ProfileScriptVersion = $ProfileScriptInfo.Version
            if ($ProfileScriptVersion -ne $LatestProfileScriptVersion) 
            {
                Save-Script -Name $($ProfileScript.BaseName) -Path "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\" -Force
                $ProfileScriptUpdated = $true
            }
        }
        if ($ProfileScriptUpdated) { Write-Host "PowerShell Profile Script(s) updated. Restart PowerShell for change to take effect." -ForegroundColor Yellow }
        else { Write-Host "PowerShell Profile Scripts are the correct version." -ForegroundColor Green }
    }
    #Check for DupreeFunctions
    $DupreeFunctionsCheck = Get-Module DupreeFunctions
    if ($null -ne $DupreeFunctionsCheck){
        Write-Host "DupreeFunctions is installed. Checking Version..." -ForegroundColor green

        $DupreeFunctionsCurrentVersion = $($DupreeFunctionsCheck.Version.Major).ToString() + "." + $($DupreeFunctionsCheck.Version.Minor).ToString() + "." + $($DupreeFunctionsCheck.Version.Build).ToString()
        try {
            $DupreeFunctionsLatestVersion = Find-Module DupreeFunctions -ErrorAction SilentlyContinue
            if ($DupreeFunctionsCurrentVersion -eq $($DupreeFunctionsLatestVersion.Version)){Write-Host "Latest version of DupreeFunctions installed." -ForegroundColor green}
            else {Write-Host "The version of DupreeFunctions installed does not match the latest." -ForegroundColor yellow}
        }
        catch {
            Write-Host "Unable to connect to PowerShell Gallery and determine latest version" -ForegroundColor red
        }
    }
}

#Check for PowerCLI and version
$PowerCLICheck = Get-Module -ListAvailable VMware.Vim
if ($null -ne $PowerCLICheck){ Write-Host "`nPowerCLI $($PowerCLICheck.Version.Major).$($PowerCLICheck.Version.Minor) is installed." -ForegroundColor green}
else { Write-Host "`nPowerCLI not found." -ForegroundColor red; Install-Module VMware.PowerCLI -Scope CurrentUser -Force }

try {
    git | Out-Null
    Write-Host "Git is installed" -ForegroundColor Green
    if ($env:githome) { 
        Write-Host "Git environment variable found." -ForegroundColor Green
        $githome = $env:githome
        Write-Host "Copying primary profile script using environment variable." -ForegroundColor Green
        Copy-Item -Path $githome\PowerShell\Profile\Microsoft.PowerShell_profile.ps1 -Destination $PROFILE -Force
    }
    else { 
        Write-Host "Git environment variable NOT found." -ForegroundColor Yellow
        if (Test-Path C:\git) { $GitPath = "C:\git" } 
        elseif (Test-Path E:\Dupree\git) { $GitPath = "E:\Dupree\git" }
        else { $GitPath = Read-Host "Please provide the git path." -ForegroundColor Yellow }
        Write-Host "Creating Git environment variable." -ForegroundColor Green
        [System.Environment]::SetEnvironmentVariable('githome', $GitPath, [System.EnvironmentVariableTarget]::User)
        Write-Host "Copying primary profile script using temporary variable." -ForegroundColor Green
        Copy-Item -Path $GitPath\PowerShell\Profile\Microsoft.PowerShell_profile.ps1 -Destination $PROFILE -Force
    }
    Write-Host "Creating ISE profile script." -ForegroundColor Green
    Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.PowerShellISE_profile.ps1")
    Write-Host "Copying VS Code profile script." -ForegroundColor Green
    Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.VSCode_profile.ps1")
}
catch [System.Management.Automation.CommandNotFoundException] {
    Write-Host "Git install not found" -ForegroundColor red
}
catch {
    Write-Host "An error occurred:"
    Write-Host $_
}

$DropboxProcess = Get-Process -Name Dropbox -ErrorAction SilentlyContinue
if ($($DropboxProcess).Count -gt 0) {
    Write-Host "Dropbox is installed and running." -ForegroundColor Green
    Write-Host "Checking for Dropbox environment variable..." -ForegroundColor Green
    if ($env:dropboxhome) { Write-Host "Dropbox environment variable found." -ForegroundColor Green }
    else {
        Write-Host "Dropbox environment variable NOT found." -ForegroundColor Yellow
        if (Test-Path "C:\Cloud\Dropbox") { $GitPath = "C:\Cloud\Dropbox" }
        else { $GitPath = Read-Host "Please provide the Dropbox path." -ForegroundColor Yellow }
        Write-Host "Creating Dropbox environment variable." -ForegroundColor Green
        [System.Environment]::SetEnvironmentVariable('dropboxhome', $GitPath, [System.EnvironmentVariableTarget]::User)
    }
}