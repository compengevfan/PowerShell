Function Set-GitPath {
    [cmdletbinding()]
    param (
    )

    try {
        git | Out-Null
        Write-Host "Git is installed" -ForegroundColor Green
        if ($env:githome) { 
            Write-Host "Git environment variable found." -ForegroundColor Green
        }
        else { 
            Write-Host "Git environment variable NOT found." -ForegroundColor Yellow
            if (Test-Path C:\git) { $GitPath = "C:\git" } 
            elseif (Test-Path E:\Dupree\git) { $GitPath = "E:\Dupree\git" }
            else { $GitPath = Read-Host "Please provide the git path." -ForegroundColor Yellow }
            Write-Host "Creating Git environment variable." -ForegroundColor Green
            [System.Environment]::SetEnvironmentVariable('githome', $GitPath, [System.EnvironmentVariableTarget]::User)
        }
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        Write-Host "Git install not found" -ForegroundColor red
    }
    catch {
        Write-Host "An error occurred:"
        Write-Host $_
    }
}

Function Sync-ProfileScript {
    if ($env:githome) {
        Write-Host "Copying primary profile script using temporary variable." -ForegroundColor Green
        Copy-Item -Path $githome\PowerShell\Profile\Microsoft.PowerShell_profile.ps1 -Destination $PROFILE -Force
        Write-Host "Creating ISE profile script." -ForegroundColor Green
        Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.PowerShellISE_profile.ps1") -Force
        Write-Host "Copying VS Code profile script." -ForegroundColor Green
        Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.VSCode_profile.ps1") -Force
    }
    else {
        Write-Host "Git environment variable NOT found." -ForegroundColor Red
    }
}

Function Import-DupreeFunctionsClean {
    [cmdletbinding()]
    param (
        [string][ValidateSet("Profile", "Git")]$Location = "Profile"
    )
    Write-Host "Re-importing DupreeFunctions module"
    Write-Host "Removing DupreeFunctions module"
    Remove-Module DupreeFunctions -ErrorAction "SilentlyContinue" -Force
    switch ($Location) {
        "Profile" {
            Write-Host "Importing DupreeFunctions From Profile Location"
            Import-Module DupreeFunctions -Force -Global 
        }
        "Git" { 
            Write-Host "Importing DupreeFunctions From Git Location"
            Import-Module $githome\PowerShell\DupreeFunctions\DupreeFunctions.psd1 -Global -force 
        }
        Default { Write-Host "Something unexpected happened." }
    }
}

Function Invoke-SendEmail {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $Subject,
        [Parameter(Mandatory = $true)] [string] $EmailBody
    )

    if ($null -ne $CredGmail) {
        $emailFrom = "HomeLab@evorigin.com"
        $emailTo = "chris.dupree@gmail.com"
        $emailServer = "smtp.gmail.com"
    
        # $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String
        Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject $Subject -body $EmailBody -Credential $CredGmail -UseSsl -port 587
    }
}

Function Invoke-Logging {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $ScriptStarted,
        [Parameter(Mandatory = $true)] [string] $ScriptName,
        [Parameter(Mandatory = $true)][ValidateSet("Succ", "Info", "Warn", "Err")] [string] $LogType,
        [Parameter(Mandatory = $true)] [string] $LogString
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

Function Save-Credential {
    [CmdletBinding()]
    Param(
        [string][ValidateSet("Auto", "AdHoc")]$Mode = "AdHoc",
        [Parameter()] [string] $Name
    )

    if (!(Test-Path $env:LOCALAPPDATA\DupreeFunctions)) {
        New-Item -Path $env:LOCALAPPDATA\DupreeFunctions -ItemType Directory
    }

    # $Name = $Name.Replace(" ", "")
    switch ($Mode) {
        "AdHoc" { 
            $Credential = Get-Credential -Message "Provide the $Name Credential."
            $CredName = "Cred" + $Name + ".xml"
            if (Test-Path $env:LOCALAPPDATA\DupreeFunctions\$CredName) { Remove-Item $env:LOCALAPPDATA\DupreeFunctions\$CredName }
            $Credential | Export-Clixml -Path $env:LOCALAPPDATA\DupreeFunctions\$CredName
            Write-Host "$Name credential created/overwritten." -ForegroundColor Green
        }
        "Auto" { 
            $Names = Get-Content $githome\PowerShell\Credentials.txt
            foreach ($Name in $Names) {
                $Credential = Get-Credential -Message "Provide the $Name Credential."
                $CredName = "Cred" + $Name + ".xml"
                if (Test-Path $env:LOCALAPPDATA\DupreeFunctions\$CredName) { Remove-Item $env:LOCALAPPDATA\DupreeFunctions\$CredName }
                $Credential | Export-Clixml -Path $env:LOCALAPPDATA\DupreeFunctions\$CredName
                Write-Host "$Name credential created/overwritten." -ForegroundColor Green
            }
        }
        Default {}
    }

    Import-Credentials
}

Function Update-Credential {
    [CmdletBinding()]
    $CredFiles = Get-ChildItem $env:LOCALAPPDATA\DupreeFunctions\Cred*.xml
    $CredToUpdate = Invoke-Menu -Objects $CredFiles -MenuColumn Name -SelectionText "Please select a credential to update." -ClearScreen:$true
    $CredName = $($CredToUpdate.Name).Replace("Cred", "").Replace(".xml", "")
    Save-Credential -Name $CredName
}

Function Remove-Credential {
    [CmdletBinding()]
    $CredFiles = Get-ChildItem $env:LOCALAPPDATA\DupreeFunctions\Cred*.xml
    $CredToDelete = Invoke-Menu -Objects $CredFiles -MenuColumn Name -SelectionText "Please select a credential to delete." -ClearScreen:$true
    Remove-Item $CredToDelete
    Import-Credentials
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
    }
    else { Write-Host "DupreeFunctions AppData folder not found." }
}

Function Show-Credentials {
    [CmdletBinding()]
    $InSession = (Get-Variable Cred*).Name
    Write-Host "Here's the list of imported credentials:" -ForegroundColor Green
    $InSession
    $CredFiles = (Get-ChildItem $env:LOCALAPPDATA\DupreeFunctions\Cred*.xml).Name
    Write-Host "`r`nHere's the list of credential files:" -ForegroundColor Green
    $CredFiles
}

Function ConvertToDN {
    [CmdletBinding()]
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
    [CmdletBinding()]
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
    [CmdletBinding()]
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

Function Update-LabBoxes {
    [CmdletBinding()]
    Param(
    )

    $destinations = @(
        "jax-pc001.evorigin.com"
        "jax-pc002.evorigin.com"
    ) | Sort-Object

    $CredImport = Import-Clixml C:\actions-runner\Cred.xml
    New-Variable -Name Credential -Value $CredImport -Scope Global

    foreach ($destination in $destinations) {
        Write-Host "Processing $destination"
        Invoke-Command -ComputerName $destination -Credential $Credential -ScriptBlock {
            #Check if PowerShell Gallery Repository is set as trusted.
            $PsgInstallPolicy = Get-PSRepository -Name PSGallery
            if ($($PsgInstallPolicy.InstallationPolicy) -ne "Trusted") {
                Write-Host "Setting PSGallery Install Policy to Trusted"
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            }
            else { Write-Host "PSGallery Install Policy already set to Trusted" }

            #Check if DupreeFunctions Exists. if not, install, if so, update.
            $DfCheck = Get-Module -ListAvailable DupreeFunctions
            if (!($DfCheck)) {
                Write-Host "Installing DupreeFunctions"
                Install-Module DupreeFunctions
            }
            else {
                Write-Host "Updating DupreeFunctions"
                Update-Module DupreeFunctions
            }
        }
    }
}