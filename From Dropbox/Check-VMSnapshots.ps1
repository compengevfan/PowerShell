Add-PSSnapin VMware.VimAutomation.Core

#$vcenter = "discography.evorigin.com"
$threshold = -3
$absthreshold = [math]::Abs($threshold)

#Connect-VIServer $vcenter | Out-Null

$snaps = Get-VM | get-snapshot | select VM,Name,SizeMB,Created,Description | sort VM | ?{$_.VM -notlike "*VDI-SOURCE*" -and $_.VM -notlike "*-VDI-*" -and $_.VM -notlike "replica*" -and $_.Created -lt ((get-date).adddays($threshold))}
$consolidations = Get-VM | sort VM | ?{$_.Extensiondata.Runtime.ConsolidationNeeded -and $_.Name -notlike "*VDI-SOURCE*" -and $_.Name -notlike "replica*"}

if($snaps -or $consolidations) {
    $global:smtpserver = "smtp.ff.p10"
    $msg = new-object Net.Mail.MailMessage
    $smtp = new-object Net.Mail.SmtpClient($global:smtpserver)
    $msg.From = "vmware_monitor@ff.p10"
    $msg.To.Add("Notify-VMSnapshots@fanatics.com")   
    $msg.subject = "$($vcenter):"
}

if($snaps) {
    if($snaps.count -gt 1) {
        $snapscount = $snaps.count
    } else { $snapscount = 1 } 
    Write-Host "$snapscount old snapshots have been found."
    $msg.subject += " $snapscount old snapshots have been found."
    $msg.body = "The following VMS have snapshots that are older than $absthreshold days:`r`n`r`n"
    foreach($snap in $snaps) {
        $prettysnapmb = "{0:N2}" -f $snap.SizeMB
        $msg.body += "VM: $($snap.VM)`r`n"
        $msg.body += "Snapshot Name: $($snap.Name)`r`n"
        $msg.body += "Snapshot Description: $($snap.Description)`r`n"
        $msg.body += "Size: $prettysnapmb MB`r`n"
        $msg.body += "Created: $($snap.Created)`r`n"
        $snapevent = Get-VIEvent -Entity $snap.VM -Types Info -Finish $snap.Created -MaxSamples 1 | Where-Object {$_.FullFormattedMessage -imatch 'Task: Create virtual machine snapshot'}
        if ($snapevent -ne $null){$msg.body += "Created By: $($snapevent.UserName)`r`n"}
        $msg.body += "`r`n"
    }
} else { Write-Host "No snapshots older than $absthreshold days found" }

if($consolidations) {
    if($consolidations.count -gt 1) {
        $consolcount = $consolidations.count
    } else { $consolcount = 1 } 
    Write-Host "$consolcount VMs are requesting consolidation."
    $msg.subject += " $consolcount VMs are requesting consolidation."
    if($snaps) { $msg.body += "`r`n" }
    $msg.body += "The following VMS are requesting consolidation:`r`n`r`n"
    foreach($consolidation in $consolidations) {
        $msg.body += "VM: $($consolidation.Name)`r`n"
        $msg.body += "PowerState: $($consolidation.PowerState)`r`n"
        $msg.body += "`r`n"
    }
} else { Write-Host "No VMS are currently requesting consolidation" }

if($snaps -or $consolidations) {
    #$smtp.Send($msg)
    $msg
}

#Disconnect-VIServer -Server $vcenter -Force -confirm:$false