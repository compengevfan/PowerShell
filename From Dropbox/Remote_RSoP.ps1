#Import-Module activedirectory

#$Computers = Get-ADComputer -SearchBase "OU=PCIcompliant-JXFC,OU=Workstations,dc=footballfanatics,dc=wh" -Filter '*'

$NumberOfComputers = $Computers.Count
$i = 1

foreach ($Computer in $Computers) 
{
    Write-Progress -Activity "Processing Computers" -status "Processing computer $i of $NumberOfComputers" -percentComplete ($i / $NumberOfComputers*100)


    if (Test-Connection $Computer.DNSHostName -Count 1 -ErrorAction SilentlyContinue)
    {
        $Server = $Computer.Name

        $Profiles = Get-WmiObject Win32_NetworkLoginProfile -ComputerName $Server | Where-Object {$_.UserType -eq "Normal Account"}

        if ($Profiles)
        {
            if (!($Profiles.Count)) { $UsertoRun = $Profiles.Name }
            else { $UsertoRun = $Profiles[0].Name }

            gpresult /s $Server /user $UsertoRun /h "C:\Temp\CS-PCI\RSoPOutput\$Server.html"
        }
        else {$Computer.DNSHostName | Out-file C:\Temp\CS-PCI\FailedWMI.txt -Append}
    }
    else {$Computer.DNSHostName | Out-file C:\Temp\CS-PCI\FailedToPing.txt -Append}

    $i++
}


#$Profiles = Get-WmiObject Win32_NetworkLoginProfile | Where-Object {$_.UserType -eq "Normal Account"}