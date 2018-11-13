[cmdletbinding()]
Param (
    $servers
)

function writeToObj($server,$status="Offline",$firmware="N/A",$driver="N/A",$wwn="N/A") {
    $obj= New-Object PSObject -Property @{
            Server = $server
            Status = $status
            Firmware = $firmware
            Driver = $driver
            WWN = $wwn
    }
    return $obj
}

if($servers.EndsWith(".txt")) { $servers = gc $servers }

$allobj = @()
foreach($v in $servers) {
    $i++
    Write-Progress -Activity "Reading data from $v" -Status "[$i/$($servers.count)]" -PercentComplete (($i/$servers.count)*100)
    if((Test-Connection -ComputerName $v -count 1 -ErrorAction 0)) {
        $hbas = gwmi -class MSFC_FCAdapterHBAAttributes -computer $v -Namespace "root\WMI" | ?{$_.model -like "QLE8242"}
        if($hbas) {
            foreach($hba in $hbas) {
                $wwn =  (($hba.NodeWWN) | ForEach-Object {"{0:x}" -f $_}) -join ":" 
                $obj = writeToObj $v "Online" $hba.firmwareversion $hba.driverversion $wwn
                $allobj += $obj
            }
        } else {
            $obj = writeToObj $v "No 8242 found"
            $allobj += $obj
        }
    } else {
        $obj = writeToObj $v 
        $allobj += $obj
    }
}

$allobj | select Server, Status, Firmware, Driver, WWN | FT
$allobj | select Server, Status, Firmware, Driver, WWN | export-csv C:\Scripts\FirmwareWindows.csv -NoTypeInformation