[CmdletBinding()]
Param(
    $CSV1 = ".\StackCheckStacks.csv",
    $CSV2 = ".\StackCheckTypes.csv"
)

$Stacks = Import-Csv $CSV1
$StackTypes = Import-Csv $CSV2
[string]$StackInfo = ""
$ServerInfo = @()

foreach ($Stack in $Stacks)
{
    $VMs = Get-Cluster $Stack.StackName | Get-VM

    foreach ($StackType in $StackTypes)
    {
        $SubVMs = $VMs | ? {$_.Name -like "*$($StackType.ServerType)*"}

        if ($SubVMs.Count -ne $StackType.NumServers)
        {
            $StackInfo += "$($Stack.Site) Stack $($Stack.StackNumber) has $($SubVMs.Count) $($StackType.Servertype) servers. Expected is $($StackType.NumServers).`n"
        }

        foreach ($SubVM in $SubVMs)
        {
            #Get CPU Count
            $CPUs = $SubVM.NumCpu
            #Get Memory Reservation Setting
            $RAMReserve = 0
            #Get RAM Amount
            $RAM = $SubVM.MemoryGB
            #Get Disk Count
            $DiskCount = (Get-HardDisk $SubVM).Count

            if ($CPUs -ne $StackType.CPUCount -or $RAM -ne $StackType.RAMAmount -or $DiskCount -ne $StackType.DiskCount)
            {
                $ServerInfo += New-Object psobject -Property @{
                    MisConfiguredServer = $SubVM.Name
                    AssignedCPU = $CPUs
                    ExpectedCPU = [int]$StackType.CPUCount
                    AssignedRAM = $RAM
                    ExpectedRAM = [int]$StackType.RAMAmount
                    AssignedDiskCount = $DiskCount
                    ExpectedDiskCount = [int]$StackType.DiskCount
                }
            }
        }
    }
}

$emailFrom = "stack_monitor@ff.p10"
$emailTo = "cdupree@fanatics.com"
$emailSubject = "Stack Server Check"
$emailServer = "smtp.ff.p10"

#Write-Host $StackInfo

$ServerInfo | Select-Object MisConfiguredServer,AssignedCPU,ExpectedCPU,AssignedRAM,ExpectedRAM,AssignedDiskCount,ExpectedDiskCount | Export-Csv ".\ServerInfoData.csv"
Send-MailMessage -smtpserver $emailServer -to $emailTo -from $emailFrom -subject $emailSubject -body $StackInfo -Attachments ".\ServerInfoData.csv"
Remove-Item ".\ServerInfoData.csv"