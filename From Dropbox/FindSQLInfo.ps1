$Servers = Get-ADComputer -Filter 'Name -notlike "ORD*"' -Property Name | Sort-Object Name

$NumberOfServers = $Servers.Count
$i = 1

$Output = @()

foreach ($Server in $Servers)
{
    Write-Progress -Activity "Processing Servers" -status "Checking Server $i of $NumberOfServers" -percentComplete ($i / $NumberOfServers*100)
    $ConnCheck = Test-Connection $Server.Name -Count 1 -ErrorAction SilentlyContinue

    if ($ConnCheck -ne $null)
    {
        $CPUInfo = Get-WmiObject -class win32_processor –computername $Server.Name -Property "NumberOfCores", "NumberOfLogicalProcessors" | Select-Object -Property "NumberOfCores", "NumberOfLogicalProcessors"

        if ($CPUInfo.Count -gt 1)
        {
            $TotalCoreCount = 0
            $TotalLogicalCount = 0

            foreach ($CPU in $CPUInfo)
            {
                $TotalCoreCount += $CPU.NumberOfCores
                $TotalLogicalCount += $CPU.NumberOfLogicalProcessors
            }
        }
        else
        {
            $TotalCoreCount = $CPUInfo.NumberOfCores
            $TotalLogicalCount = $CPUInfo.NumberOfLogicalProcessors
        }

        $BaseKey = "SOFTWARE\Microsoft\Microsoft SQL Server"
    
        $InstanceKey = $BaseKey + "\Instance Names\SQL"

        $SQLInstances = Get-RegValue -ComputerName $Server.Name -Key $InstanceKey -ErrorAction SilentlyContinue

        foreach ($SQLInstance in $SQLInstances)
        {
            $SQLRegValue = $BaseKey + "\" + $SQLInstance.Data + "\Setup"

            $SQLEdition = Get-RegValue -ComputerName $Server.Name -Key $SQLRegValue -Value Edition
            $SQLVersion = Get-RegValue -ComputerName $Server.Name -Key $SQLRegValue -Value Version
            $SQLPatch = Get-RegValue -ComputerName $Server.Name -Key $SQLRegValue -Value PatchLevel
        
            $Output += New-Object psobject -Property @{
                ComputerName = $SQLInstance.ComputerName
                InstanceName = $SQLInstance.Data
                CoreCount = $TotalCoreCount
                LogicalCount = $TotalLogicalCount
                Edition = $SQLEdition.Data
                Version = $SQLVersion.Data
                Patch = $SQLPatch.Data
            }
        }
    }
    $i++
}

$Output | Select-Object ComputerName,InstanceName,CoreCount,LogicalCount,Edition,Version,Patch | Export-Csv ".\SQL.csv" -Append