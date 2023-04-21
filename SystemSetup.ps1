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
else { Write-Host "`nPowerCLI not found." -ForegroundColor red}

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