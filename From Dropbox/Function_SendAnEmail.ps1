Function SendAnEmail
{
    Param ([Parameter(Mandatory=$True)] [string]$emailserver,
            [Parameter(Mandatory=$True)] [string] $emailTo,
            [Parameter(Mandatory=$True)] [string] $emailFrom,
            [Parameter(Mandatory=$True)] [string] $emailSubject,
            [Parameter(Mandatory=$True)] [string] $emailbody)

    Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject $emailSubject -body $emailbody
}