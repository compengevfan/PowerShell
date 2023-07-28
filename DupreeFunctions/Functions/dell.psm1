Function Invoke-DfDracReset {
    [cmdletbinding()]
    param (
        [Parameter()] [ValidateSet("1", "2", "3", "All")] [string] $DracToReset,
        [Parameter()] [ValidateSet("soft", "hard")] [string] $ResetMode = "soft"
    )

    $ErrorActionPreference = "Stop"

    $ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
    $ScriptName = $MyInvocation.MyCommand.Name

    # $LoggingSuccSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Succ"}
    $LoggingInfoSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Info" }
    # $LoggingWarnSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Warn"}
    # $LoggingErrSplat = @{ScriptStarted = $ScriptStarted; ScriptName = $ScriptName; LogType = "Err"}

    if ($null -eq $CredDrac) {
        Throw "Drac Cred not found!"
    }
    $DracUserName = $CredDrac.UserName
    $DracPassword = $CredDrac.GetNetworkCredential().Password

    if ($DracToReset -eq "All") {
        $LocalHosts = "rac-esx1.evorigin.com", "rac-esx2.evorigin.com", "rac-esx3.evorigin.com"

        foreach ($LocalHost in $LocalHosts) {
            Invoke-DfLogging @LoggingInfoSplat -LogString "Issuing command to reset iDrac on $LocalHost"
            Invoke-Command -ScriptBlock { racadm -r $LocalHost -u $DracUserName -p $DracPassword racreset $ResetMode }
        }
    }
    else {
        Invoke-DfLogging @LoggingInfoSplat -LogString "Issuing command to reset iDrac on rac-esx$DracToReset.evorigin.com"
        Invoke-Command -ScriptBlock { racadm -r "rac-esx$DracToReset.evorigin.com" -u $DracUserName -p $DracPassword racreset $ResetMode }
    }
}