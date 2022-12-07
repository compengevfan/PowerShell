Function Invoke-Logging {
    Param(
        [Parameter(Mandatory = $true)] [string] $ScriptStarted,
        [Parameter(Mandatory = $true)] [string] $ScriptName,
        [Parameter(Mandatory = $true)][ValidateSet("Succ", "Info", "Warn", "Err")] [string] $LogType,
        [Parameter()] [string] $LogString
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$TimeStamp $LogString" | Out-File .\~Logs\"$ScriptName $ScriptStarted.log" -append

    Write-Host -F DarkGray "[" -NoNewLine
    Write-Host -F Green "*" -NoNewLine
    Write-Host -F DarkGray "] " -NoNewLine
    Switch ($LogType) {
        Succ { Write-Host -F Green $LogString }
        Info { Write-Host -F White $LogString }
        Warn { Write-Host -F Yellow $LogString }
        Err { Write-Host -F Red $LogString }
    }
}

Function Invoke-SystemSetup {
    #Check for PowerCLI and version
    $PowerCLICheck = Get-Module -ListAvailable VMware.Vim
    if ($null -ne $PowerCLICheck) { Write-Host "`nPowerCLI $($PowerCLICheck.Version.Major).$($PowerCLICheck.Version.Minor) is installed." -ForegroundColor green }
    else { 
        Write-Host "`nPowerCLI not found. Installing..." -ForegroundColor red
        Install-Module VMware.PowerCLI -Scope CurrentUser -Force
    }

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
            if (Test-Path C:\git\PowerShell) { $GitPath = "C:\git\PowerShell" } 
            else { $GitPath = Read-Host "Please provide the git path." -ForegroundColor Yellow }
            Write-Host "Creating Git environment variable." -ForegroundColor Green
            [System.Environment]::SetEnvironmentVariable('githome', $GitPath, [System.EnvironmentVariableTarget]::User)
            Write-Host "Copying primary profile script using temporary variable." -ForegroundColor Green
            Copy-Item -Path $GitPath\Profile\Microsoft.PowerShell_profile.ps1 -Destination $PROFILE -Force
        }
        Write-Host "Creating ISE profile script." -ForegroundColor Green
        Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.PowerShellISE_profile.ps1")
        Write-Host "Copying VS Code profile script." -ForegroundColor Green
        Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.VSCode_profile")
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        Write-Host "Git install not found" -ForegroundColor red
    }
    catch {
        Write-Host "An error occurred:"
        Write-Host $_
    }

    $DropboxProcess = Get-Process -Name Dropbox
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

    Write-Host "System setup complete. Close this window and open a new one."
}

Function Save-Credential {
    Param(
        [Parameter()] [string] $Name
    )

    if (!(Test-Path $env:LOCALAPPDATA\DupreeFunctions)) {
        New-Item -Path $env:LOCALAPPDATA\DupreeFunctions -ItemType Directory
    }

    $Name = $Name.Replace(" ", "")

    $Credential = Get-Credential -Message "Provide the $Name Credential."
    $CredName = "Cred" + $Name + ".xml"
    if (Test-Path $env:LOCALAPPDATA\DupreeFunctions\$CredName) { Remove-Item $env:LOCALAPPDATA\DupreeFunctions\$CredName }
    $Credential | Export-Clixml -Path $env:LOCALAPPDATA\DupreeFunctions\$CredName
    Write-Host "$Name credential created/overwritten." -ForegroundColor Green

    Import-Credentials
}

Function Update-Credential {
    $CredFiles = Get-ChildItem $env:LOCALAPPDATA\DupreeFunctions\Cred*.xml

    $CredToUpdate = Invoke-Menu -Objects $CredFiles -MenuColumn Name -SelectionText "Please select a credential to update." -ClearScreen:$true

    $CredName = $($CredToUpdate.Name).Replace("Cred","").Replace(".xml","")

    Save-Credential -Name $CredName
}

Function Import-Credentials {
    Remove-Variable Cred* -Scope Global

    if (Test-Path $env:LOCALAPPDATA\DupreeFunctions) {
        $CredCount = 0
        $CredFiles = Get-ChildItem $env:LOCALAPPDATA\DupreeFunctions\Cred*.xml
        foreach ($CredFile in $CredFiles) {
            $CredImport = Import-Clixml $CredFile
            New-Variable -Name $CredFile.BaseName -Value $CredImport -Scope Global
            $CredCount += 1
        }

        Write-Host "$CredCount Credential(s) Imported."
    } else { Write-Host "DupreeFunctions AppData folder not found."}
}

Function ConvertToDN {
    Param(
        [Parameter(Mandatory = $true)] [string] $Domain,
        [Parameter(Mandatory = $true)] [string] $OUPath
    )

    $DN = ""

    $OUPath.Split('/') | ForEach-Object { $DN = "OU=" + $_ + "," + $DN }
    $Domain.Split('.') | ForEach-Object { $DN = $DN + "DC=" + $_ + "," }

    $DN = $DN.Substring(0, $DN.Length - 1)

    return $DN
}

Function Convert-PhoneticAlphabet {
    ##### ** THIS SCRIPT IS PROVIDED WITHOUT WARRANTY, USE AT YOUR OWN RISK **

    <#
.SYNOPSIS
    Converts an alphanumeric string into the NATO Phonetic Alphabet equivalent.

.DESCRIPTION
    The advanced function will convert an alphanumeric string into the NATO phonetic alphabet.
	
.PARAMETER String
    This is the default, required parameter. It is the string that the advanced function will convert.

.EXAMPLE
    Convert-TMNatoAlphabet -String '12abc3'
    This example will convert the string, 12abc3, to its NATO phonetic alphabet equivalent. It will return, "One Two Alpha Bravo Charlie Three."

.EXAMPLE
    Convert-TMNatoAlphabet -String '1p2h3-cc'
    This example will attempt to convert the string, 1p2h3-cc, to its NATO phonetic alphabet equivalent. Since it contains an invalid character (-), it will return, "String contained illegal character(s)."

.EXAMPLE
    Convert-TMNatoAlphabet '1ph3cc'
    This example will convert the string, 1ph3cc, to its NATO phonetic alphabet equivalent. It will return, "One Papa Hotel Three Charlie Charlie."

.NOTES
    NAME: Convert-TMNatoAlphabet
    AUTHOR: Tommy Maynard
    LASTEDIT: 08/21/2014
    VERSION 1.1
        -Changed seperate alpha and numeric hashes into one, alphanumeric hash (numbers are being stored as strings)
    VERSION 1.2
        -Edited the logic that handles the conversion (no need for If and nested If - Initial If handles a-z 0-9 check)
        -Added string cleanup inside If statement
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, Position = 0)]
        [string]$String
    )

    Begin {
        Write-Verbose -Message 'Creating alphanumeric hash table'
        $Hash = @{'A' = ' Alpha '; 'B' = ' Bravo '; 'C' = ' Charlie '; 'D' = ' Delta '; 'E' = ' Echo '; 'F' = ' Foxtrot '; 'G' = ' Golf '; 'H' = ' Hotel '; 'I' = ' India '; 'J' = ' Juliet '; 'K' = ' Kilo '; 'L' = ' Lima '; 'M' = ' Mike '; 'N' = ' November '; 'O' = ' Oscar '; 'P' = ' Papa '; 'Q' = ' Quebec '; 'R' = ' Romeo '; 'S' = ' Sierra '; 'T' = ' Tango '; 'U' = ' Uniform '; 'V' = ' Victory '; 'W' = ' Whiskey '; 'X' = ' X-ray '; 'Y' = ' Yankee '; 'Z' = ' Zulu '; '0' = ' Zero '; '1' = ' One '; '2' = ' Two '; '3' = ' Three '; '4' = ' Four '; '5' = ' Five '; '6' = ' Six '; '7' = ' Seven '; '8' = ' Eight '; '9' = ' Nine ' }
    
    } # End Begin

    Process {
        Write-Verbose -Message 'Checking string for illegal charcters'
        If ($String -match '^[a-zA-Z0-9]+$') {
            Write-Verbose -Message 'String does not have any illegal characters'
            $String = $String.ToUpper()

            Write-Verbose -Message 'Creating converted string'
            For ($i = 0; $i -le $String.Length; $i++) {
                [string]$Character = $String[$i]
                $NewString += $Hash.Get_Item($Character)
            }

            Write-Verbose -Message 'Cleaning up converted string'
            $NewString = ($NewString.Trim()).Replace('  ', ' ')
            Write-Output $NewString
        }
        Else {
            Write-Output -Verbose 'String contained illegal character(s).'
        }
    } # End Process
} # End Function

Function Get-FileName {
    Param(
        [Parameter(Mandatory = $true)] [string] $Filter
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $initialDirectory = Get-Location
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "$Filter (*.$Filter)| *.$Filter"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

Function Invoke-Menu {
    Param(
        [Parameter(Mandatory = $true)] $Objects,
        [Parameter(Mandatory = $true)] [string] $MenuColumn,
        [Parameter(Mandatory = $true)] [string] $SelectionText,
        [Parameter(Mandatory = $true)] [bool] $ClearScreen
    )

    if ($ClearScreen) { Clear-Host }

    $i = 1
    $Objects_In_Array = @()

    foreach ($Object in $Objects) {
        $Objects_In_Array += New-Object -Type PSObject -Property (@{
                Identifier = $i
                MenuData   = ($Object).$MenuColumn
            })
        $i++
    }

    foreach ($Object_In_Array in $Objects_In_Array) { Write-Host $("`t" + $Object_In_Array.Identifier + ". " + $Object_In_Array.MenuData) }

    $Selection = Read-Host $SelectionText

    $ArraySelection = $Objects_In_Array[$Selection - 1]

    $ReturnObject = $Objects | Where-Object $MenuColumn -eq $ArraySelection.MenuData

    return $ReturnObject
}