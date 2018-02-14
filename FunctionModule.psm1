Function Check-PowerCLI
{
    Param(
    )

    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
        $PrevPath = Get-Location

	    write-host ("Adding PowerCLI...")
        if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts")
        {
            cd "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts"
	        .\Initialize-PowerCLIEnvironment.ps1
        }
        if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts")
        {
            cd "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts"
            .\Initialize-PowerCLIEnvironment.ps1
        }

        cd $PrevPath

	    write-host ("Loaded PowerCLI.")
    }
}

function Connect-vCenter
{
    Param(
        [Parameter()] [string] $vCenter
    )

    $ConnectedvCenter = $global:DefaultVIServers
    if ($ConnectedvCenter.Count -eq 0)
    {
        if ($vCenter -eq $null -or $vCenter -eq "") { $vCenter = Read-Host "Please provide the name of a vCenter server..." }
        do
        {
            if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) { Write-Host "Attempting to connect to vCenter server $vCenter" }
        
            Connect-VIServer $vCenter | Out-Null
            $ConnectedvCenter = $global:DefaultVIServers

            if ($ConnectedvCenter.Count -eq 0 -or $ConnectedvCenter -eq $null) { Write-Host "vCenter Connection Failed. Please try again or press Control-C to exit..."; Start-Sleep -Seconds 2 }
        } while ($ConnectedvCenter.Count -eq 0)
    }
}

Function DoLogging
{
    Param(
        [Parameter(Mandatory=$true)][ValidateSet("Succ","Info","Warn","Err")] [string] $LogType,
        [Parameter()] [string] $LogString
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$TimeStamp $LogString" | Out-File .\~Logs\"$ScriptName $ScriptStarted.log" -append

    Write-Host -F DarkGray "[" -NoNewLine
    Write-Host -F Green "*" -NoNewLine
    Write-Host -F DarkGray "] " -NoNewLine
    Switch ($LogType)
    {
        Succ { Write-Host -F Green $LogString }
        Info { Write-Host -F White $LogString }
        Warn { Write-Host -F Yellow $LogString }
        Err
        {
            Write-Host -F Red $LogString
            if ($SendEmail) { $EmailBody = Get-Content .\~Logs\"$ScriptName $ScriptStarted.log" | Out-String; Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Cloud-O-Mite Encountered an Error" -body $EmailBody }
        }
    }
}

Export-ModuleMember -Function *