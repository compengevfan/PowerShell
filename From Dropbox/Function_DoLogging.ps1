[CmdletBinding()]
Param(
)

Function Invoke-Logging
{
    Param(
        [Parameter(Mandatory=$true)][ValidateSet("Succ","Info","Warn","Err")] [string] $LogType,
        [Parameter()] [string] $LogString
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$TimeStamp $LogString" | Out-File .\Logs\$InputFileName + " " + $ScriptStarted + ".txt" -append

    Write-Host -F DarkGray "[" -NoNewLine
    Write-Host -F Green "*" -NoNewLine
    Write-Host -F DarkGray "] " -NoNewLine
    Switch ($LogType)
    {
        Succ { Write-Host $LogString -F Green }
        Info { Write-Host $LogString }
        Warn { Write-Host -F Yellow $LogString }
        Err
        {
            Write-Host -F Red $LogString
            Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject "Cloud-O-Mite Encountered an Error" -body (Get-Content .\Logs\$InputFileName + " " + $ScriptStarted + ".txt")
        }
    }
}

Invoke-Logging -LogType Info -LogString "This is a log entry..."