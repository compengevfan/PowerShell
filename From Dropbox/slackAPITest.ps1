# Get the Slack User List
$slackToken = "SLACK_API+KEY_GOES_HERE"
$userList = Invoke-RestMethod ("https://slack.com/api/users.list?token={0}" -f $slackToken)

# Set up AD query
$strFilter = "(&(objectCategory=User)(objectCategory=Person)(Department=IT))"

$objDomain = New-Object System.DirectoryServices.DirectoryEntry

$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchRoot = $objDomain
$objSearcher.PageSize = 10000
$objSearcher.Filter = $strFilter
$objSearcher.SearchScope = "Subtree"

$colProplist = "name", "userprincipalname", "givenname", "useraccountcontrol"
foreach ($i in $colPropList){$objSearcher.PropertiesToLoad.Add($i)}

$colResults = $objSearcher.FindAll()

# Loop through the slack users

$badSlackIDs = @();
$disabledFanaticsIDs = @();
$nonFanaticsEmails = @();
ForEach ($member in $UserList.members) {
    if (!$member.deleted -and !$member.is_bot) {
        # ID not the sa,e as email
        $slackID = $member.name.ToLower();
        if (!($member.profile.email).ToLower().EndsWith("@fanatics.com")){
            $nonFanaticsEmails += "{0}`n" -f $member.profile.email;
            continue;
        }
        $fanaticsID = ($member.profile.email -replace '@fanatics.com', '').ToLower();
        if ($slackID -ne $fanaticsID) { $badSlackIDs += "{0} email is {1}`n" -f $slackID, $member.profile.email}
        # Loop through AD
        foreach ($objResult in $colResults)
        {
            $objItem = $objResult.Properties;
            $fanaticsADID = ($objItem.userprincipalname -replace "@footballfanatics.wh", "").ToLower()
            if ( ($fanaticsID -eq $fanaticsADID) -and ($objItem.useraccountcontrol -eq 514) ) {$disabledFanaticsIDs += "Disabled user {0} is active in slack as {1}`n" -f $fanaticsADID, $slackID;}

        }
    } 
}
Write-Host "``nDisabled Fanatics IDs in Slack`n==============================`n"
Write-Host $disabledFanaticsIDs
Write-Host "`nNon-Fanatics Emails`n===================`n"
Write-Host $nonFanaticsEmails
Write-Host "BAD Slack IDs`n============`n";
Write-Host $badSlackIDs


