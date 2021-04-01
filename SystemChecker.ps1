[CmdletBinding()]
Param(
)

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
if ($NuGetCheck -ne $null) {Write-Host "`nNuGet Version $($NuGetCheck.Version) installed." -ForegroundColor green; $NuGetGood = $true}
else {Write-Host "`nNuGet is not installed."-ForegroundColor red; $NuGetGood = $false}

$PowerShellGetCheck = Get-PackageProvider | Where-Object {$_.Name -eq "PowerShellGet"}
if ($NuGetCheck -ne $null) {Write-Host "`nPowerShellGet Version $($PowerShellGetCheck.Version) installed." -ForegroundColor green; $PowerShellGetGood = $true}
else {Write-Host "`nPowerShellGet is not installed." -ForegroundColor red; $PowerShellGetGood = $false}

if ($NuGetGood -and $PowerShellGetGood) {
    #Check for DupreeFunctions
    $DupreeFunctionsCheck = Get-Module DupreeFunctions
    if ($DupreeFunctionsCheck -ne $null){
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
if ($PowerCLICheck -ne $null){ Write-Host "`nPowerCLI $($PowerCLICheck.Version.Major).$($PowerCLICheck.Version.Minor) is installed." -ForegroundColor green}
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