[CmdletBinding()]
Param(
)

#Requires -Version 7.2

#Display .NET Versions Installed
Write-Host ".NET version installed: " -NoNewline
$dotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release
switch ($dotNetVersion) {
    378389 { Write-Host "4.5" }
    {($_ -eq 378675) -or ($_ -eq 378758)} { Write-Host "4.5.1" }
    379893 { Write-Host "4.5.2" }
    {($_ -eq 393295) -or ($_ -eq 393297)} { Write-Host "4.6" }
    {($_ -eq 394254) -or ($_ -eq 394271)} { Write-Host "4.6.1" }
    {($_ -eq 394802) -or ($_ -eq 394806)} { Write-Host "4.6.2" }
    {($_ -eq 460798) -or ($_ -eq 460805)} { Write-Host "4.7" }
    {($_ -eq 461308) -or ($_ -eq 461310)} { Write-Host "4.7.1" }
    {($_ -eq 461808) -or ($_ -eq 461814)} { Write-Host "4.7.2" }
    {($_ -eq 528040) -or ($_ -eq 528372) -or ($_ -eq 528049)} { Write-Host "4.8" }
    Default { Write-Host "Unknown build $dotNetVersion found."}
}

#Display PowerShell Version
Write-Host "`nPowerShell Version Installed:"
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
    if ($null -eq (Test-Path -Path "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell")) 
    {
        New-Item -Path "$([Environment]::GetFolderPath("MyDocuments"))" -Name "WindowsPowerShell" -ItemType "directory"
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
        $ProfileScripts = Get-ChildItem "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\*" -Include *.ps1
        foreach ($ProfileScript in $ProfileScripts) 
        {
            $ProfileScriptInfo = Test-ScriptFileInfo $ProfileScript -ErrorAction SilentlyContinue
            $ProfileScriptVersion = $ProfileScriptInfo.Version
            if ($ProfileScriptVersion -ne $LatestProfileScriptVersion) 
            {
                Save-Script -Name $($ProfileScript.BaseName) -Path "$([Environment]::GetFolderPath("MyDocuments"))\WindowsPowerShell\" -Force
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
else { Write-Host "`nPowerCLI not found." -ForegroundColor red}

#Check for GitHub environment variable, if not exists, create it if Github is installed
$GitHubInstalled = Read-Host "Is GitHub installed? (y/n)"
if ($GitHubInstalled -eq "y"){
    Write-Host "Checking for GitHub Environment Variable..."
    if ($env:githubhome) { Write-Host "Github path found." -ForegroundColor Green }
    else { 
        Write-Host "Github path NOT found." -ForegroundColor Yellow
        $GitHubPath = Read-Host "Please provide the path."
        Write-Host "Creating GitHub environment variable."
        [System.Environment]::SetEnvironmentVariable('githubhome',$GitHubPath,[System.EnvironmentVariableTarget]::User)
    }
}

$GitInstalled = Read-Host "Is Git installed? (y/n)"
if ($GitInstalled -eq "y"){
    Write-Host "Checking for Git Environment Variable..."
    if ($env:githome) { Write-Host "Git path found." -ForegroundColor Green }
    else { 
        Write-Host "Git path NOT found." -ForegroundColor Yellow
        $GitPath = Read-Host "Please provide the path."
        Write-Host "Creating Git environment variable."
        [System.Environment]::SetEnvironmentVariable('githome',$GitPath,[System.EnvironmentVariableTarget]::User)
    }
}

$DropboxInstalled = Read-Host "Is Dropbox installed (y/n)"
if ($DropboxInstalled -eq "y"){
    Write-Host "Checking for Dropbox Environment Variable..."
    if ($env:dropboxhome) { Write-Host "Dropbox path found." -ForegroundColor Green }
    else { 
        Write-Host "Dropbox path NOT found." -ForegroundColor Yellow
        $GitPath = Read-Host "Please provide the path."
        Write-Host "Creating Dropbox environment variable."
        [System.Environment]::SetEnvironmentVariable('dropboxhome',$GitPath,[System.EnvironmentVariableTarget]::User)
    }
}