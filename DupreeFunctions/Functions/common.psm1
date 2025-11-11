Function Set-DfGitPath {
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

Function Sync-DfProfileScript {
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

Function Import-DfDupreeFunctionsClean {
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

Function Invoke-DfSendEmail {
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

Function Invoke-DfLogging {
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

Function Save-DfCredential {
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

    Import-DfCredentials
}

Function Update-DfCredential {
    [CmdletBinding()]
    $CredFiles = Get-ChildItem $env:LOCALAPPDATA\DupreeFunctions\Cred*.xml
    $CredToUpdate = Invoke-DfMenu -Objects $CredFiles -MenuColumn Name -SelectionText "Please select a credential to update." -ClearScreen:$true
    $CredName = $($CredToUpdate.Name).Replace("Cred", "").Replace(".xml", "")
    Save-DfCredential -Name $CredName
}

Function Remove-DfCredential {
    [CmdletBinding()]
    $CredFiles = Get-ChildItem $env:LOCALAPPDATA\DupreeFunctions\Cred*.xml
    $CredToDelete = Invoke-DfMenu -Objects $CredFiles -MenuColumn Name -SelectionText "Please select a credential to delete." -ClearScreen:$true
    Remove-Item $CredToDelete
    Import-DfCredentials
}

Function Import-DfCredentials {
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
    else { 
        Write-Host "DupreeFunctions AppData folder not found. Creating..." 
        New-Item -path $env:LOCALAPPDATA -Name "DupreeFunctions" -ItemType Directory
    }
}

Function Show-DfCredentials {
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

Function Get-DfFileName {
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

Function Invoke-DfMenu {
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

Function Update-DfLabBoxes {
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

Function Update-DfModuleVersion{
    $PsgModuleVersion = Find-Module DupreeFunctions
    $OldPsgModuleVersion = $PsgModuleVersion.Version.Major.ToString() + "." + $PsgModuleVersion.Version.Minor.ToString() + "." + $PsgModuleVersion.Version.Build.ToString()
    $NewPsgModuleVersion = $PsgModuleVersion.Version.Major.ToString() + "." + $PsgModuleVersion.Version.Minor.ToString() + "." + $(($PsgModuleVersion.Version.Build + 1)).ToString()

    $PsdContent = Get-Content C:\Git\PowerShell\DupreeFunctions\DupreeFunctions.psd1 -Raw
    $NewPsdContent = $PsdContent.Replace("$OldPsgModuleVersion","$NewPsgModuleVersion")
    $NewPsdContent | Out-File C:\actions-runner\_work\PowerShell\PowerShell\DupreeFunctions\DupreeFunctions.psd1 -Force
}

Function Invoke-UserSetup {
    [CmdletBinding()]
    Param(
    )

    #Display PowerShell Version
    Write-Host "`nPowerShell Version:"
    $CurrentPsVersion = $PSVersionTable.PSVersion
    # $Hostname = $env:COMPUTERNAME
    $DomainName = $env:USERDNSDOMAIN

    try {
        git | Out-Null
        Write-Host "Git is installed" -ForegroundColor Green

        if ($DomainName -eq "EVORIGIN.COM") {
            Write-Host "HomeLab Computer Detected."
            $GitPath = "C:\git"
        }
        else {
            Write-Host "Work Computer Detected."
            $GitPath = "E:\Dupree\git"
        }
        if ($null -eq $(Test-Path $GitPath)) { New-Item -Path $GitPath -ItemType Directory }

        #Check for/create git folder and set githome environment variable
        if ($env:githome) { Write-Host "githome environment variable found." -ForegroundColor Green }
        else {
            Write-Host "Creating githome Environment Variable" -ForegroundColor Yellow
            [System.Environment]::SetEnvironmentVariable('githome', $GitPath, [System.EnvironmentVariableTarget]::User)
        }
        
        #Clone repos to git folder
        if ($null -eq $(Test-Path $GitPath\Ansible)) { git clone https://github.com/compengevfan/Ansible.git $GitPath\Ansible }
        else { Write-Host "Ansible repo already cloned to this machine." }
        if ($null -eq $(Test-Path $GitPath\k8s)) { git clone https://github.com/compengevfan/Ansible.git $GitPath\k8s }
        else { Write-Host "k8s repo already cloned to this machine." }
        if ($null -eq $(Test-Path $GitPath\PowerShell)) { git clone https://github.com/compengevfan/Ansible.git $GitPath\PowerShell }
        else { Write-Host "PowerShell repo already cloned to this machine." }
        if ($null -eq $(Test-Path $GitPath\vmbuildfiles)) { git clone https://github.com/compengevfan/Ansible.git $GitPath\vmbuildfiles }
        else { Write-Host "vmbuildfiles repo already cloned to this machine." }
        
        #Copy powershell profile appropriate location from PowerShell Repo
        if ($CurrentPsVersion.Major -eq 5) {
            if (!($(Test-Path $PROFILE))) {
                Write-Host "Copying primary profile script to PowerShell 5.1 Destination." -ForegroundColor Green
                Copy-Item -Path $GitPath\PowerShell\Profile\Microsoft.PowerShell_profile.ps1 -Destination $PROFILE
            }
            if (!($(Test-Path "$env:UserProfile\PowerShell\Microsoft.PowerShellISE_profile.ps1"))) {
                Write-Host "Creating ISE profile script to PowerShell 5.1 Destination." -ForegroundColor Green
                Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.PowerShellISE_profile.ps1")
            }
            if (!($(Test-Path "$env:UserProfile\PowerShell\Microsoft.VSCode_profile.ps1"))) {
                Write-Host "Creating VS Code profile script to PowerShell 5.1 Destination." -ForegroundColor Green
                Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.VSCode_profile.ps1")
            }
        }
        if ($CurrentPsVersion.Major -eq 7) {
            if (!($(Test-Path $PROFILE))) {
                Write-Host "Copying primary profile script to PowerShell 7 Destination." -ForegroundColor Green
                Copy-Item -Path "$GitPath\PowerShell\Profile\Microsoft.PowerShell_profile.ps1" -Destination $PROFILE
            }
            if (!($(Test-Path "$env:UserProfile\PowerShell\Microsoft.PowerShellISE_profile.ps1"))) {
                Write-Host "Creating ISE profile script to PowerShell 7 Destination." -ForegroundColor Green
                Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.PowerShellISE_profile.ps1")
            }
            if (!($(Test-Path "$env:UserProfile\PowerShell\Microsoft.VSCode_profile.ps1"))) {
                Write-Host "Creating VS Code profile script to PowerShell 7 Destination." -ForegroundColor Green
                Copy-Item -Path $PROFILE -Destination $PROFILE.Replace("Microsoft.PowerShell_profile.ps1", "Microsoft.VSCode_profile.ps1")
            }
        }

        #Check for/create DupreeFunctions appdata folder
        if ($null -eq $(Test-Path "$env:LOCALAPPDATA\DupreeFunctions")) { 
            Write-Host "Creating DupreeFunctions AppData folder."
            New-Item -path $env:LOCALAPPDATA -Name "DupreeFunctions" -ItemType Directory 
        }
        else { Write-Host "DupreeFunctions AppData folder found." }
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        Write-Host "Git install not found" -ForegroundColor red
    }
    catch {
        Write-Host "An error occurred:"
        Write-Host $_
    }
}

Function Get-SnmpData {
    [CmdletBinding()]
    Param(
    )

    #Storage1
    #NVMe - NFS
    $Storage1_NVMe_Health = snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.1.1.1.3.4
    $Storage1_NVMe_AvailableSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.4.4)
    $Storage1_NVMe_UsedSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.3.4)
    $Storage1_NVMe_UsedPercent = (($Storage1_NVMe_UsedSpace / ($Storage1_NVMe_AvailableSpace + $Storage1_NVMe_UsedSpace)) * 100)

    #SSD - NFS
    $Storage1_SSD_Health = snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.1.1.1.3.5
    $Storage1_SSD_AvailableSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.4.5)
    $Storage1_SSD_UsedSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.3.5)
    $Storage1_SSD_UsedPercent = (($Storage1_SSD_UsedSpace / ($Storage1_SSD_AvailableSpace + $Storage1_SSD_UsedSpace)) * 100)

    #HDD - Storage
    $Storage1_HDD_Health = snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.1.1.1.3.2
    $Storage1_HDD_AvailableSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.4.2)
    $Storage1_HDD_UsedSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.3.2)
    $Storage1_HDD_UsedPercent = (($Storage1_HDD_UsedSpace / ($Storage1_HDD_AvailableSpace + $Storage1_HDD_UsedSpace)) * 100)

    #HDD2 - Media Backup
    $Storage1_HDD2_Health = snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.1.1.1.3.3
    $Storage1_HDD2_AvailableSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.4.3)
    $Storage1_HDD2_UsedSpace = [int64](snmpget -v 2c -c public -Oqv storage1.evorigin.com .1.3.6.1.4.1.50536.1.2.1.1.3.3)
    $Storage1_HDD2_UsedPercent = (($Storage1_HDD2_UsedSpace / ($Storage1_HDD2_AvailableSpace + $Storage1_HDD2_UsedSpace)) * 100)

    $storage1Data = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        NVMe = @{
            Health = $Storage1_NVMe_Health
            AvailableSpace = $Storage1_NVMe_AvailableSpace
            UsedSpace = $Storage1_NVMe_UsedSpace
            UsedPercent = [math]::Round($Storage1_NVMe_UsedPercent, 2)
        }
        SSD = @{
            Health = $Storage1_SSD_Health
            AvailableSpace = $Storage1_SSD_AvailableSpace
            UsedSpace = $Storage1_SSD_UsedSpace
            UsedPercent = [math]::Round($Storage1_SSD_UsedPercent, 2)
        }
        HDD = @{
            Health = $Storage1_HDD_Health
            AvailableSpace = $Storage1_HDD_AvailableSpace
            UsedSpace = $Storage1_HDD_UsedSpace
            UsedPercent = [math]::Round($Storage1_HDD_UsedPercent, 2)
        }
        HDD2 = @{
            Health = $Storage1_HDD2_Health
            AvailableSpace = $Storage1_HDD2_AvailableSpace
            UsedSpace = $Storage1_HDD2_UsedSpace
            UsedPercent = [math]::Round($Storage1_HDD2_UsedPercent, 2)
        }
    }

    $storage1Data | ConvertTo-Json -Depth 3 | Set-Content -Path "storage1_data.json"

    #Storage3
    #Volume1 - NFS
    $Storage3_Vol1_Health = snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.4.1
    $Storage3_Vol1_TotalSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.6.1)
    $Storage3_Vol1_FreeSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.7.1)
    $Storage3_Vol1_UsedPercent = ((($Storage3_Vol1_TotalSize - $Storage3_Vol1_FreeSize) / $Storage3_Vol1_TotalSize) * 100)

    #Volume2 - Storage
    $Storage3_Vol2_Health = snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.4.2
    $Storage3_Vol2_TotalSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.6.2)
    $Storage3_Vol2_FreeSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.7.2)
    $Storage3_Vol2_UsedPercent = ((($Storage3_Vol2_TotalSize - $Storage3_Vol2_FreeSize) / $Storage3_Vol2_TotalSize) * 100)

    #Volume3 - Media
    $Storage3_Vol3_Health = snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.4.3
    $Storage3_Vol3_TotalSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.6.3)
    $Storage3_Vol3_FreeSize = [int64](snmpget -v 2c -c public -Oqv storage3.evorigin.com .1.3.6.1.4.1.44738.5.1.1.7.3)
    $Storage3_Vol3_UsedPercent = ((($Storage3_Vol3_TotalSize - $Storage3_Vol3_FreeSize) / $Storage3_Vol3_TotalSize) * 100)

    $storage3Data = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Volume1 = @{
            Health = $Storage3_Vol1_Health
            TotalSize = $Storage3_Vol1_TotalSize
            FreeSize = $Storage3_Vol1_FreeSize
            UsedPercent = [math]::Round($Storage3_Vol1_UsedPercent, 2)
        }
        Volume2 = @{
            Health = $Storage3_Vol2_Health
            TotalSize = $Storage3_Vol2_TotalSize
            FreeSize = $Storage3_Vol2_FreeSize
            UsedPercent = [math]::Round($Storage3_Vol2_UsedPercent, 2)
        }
        Volume3 = @{
            Health = $Storage3_Vol3_Health
            TotalSize = $Storage3_Vol3_TotalSize
            FreeSize = $Storage3_Vol3_FreeSize
            UsedPercent = [math]::Round($Storage3_Vol3_UsedPercent, 2)
        }
    }

    $storage3Data | ConvertTo-Json -Depth 3 | Set-Content -Path "~/snmp_files/storage3_data.json"
}