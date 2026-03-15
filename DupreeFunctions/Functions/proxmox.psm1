function Invoke-DfProxmoxSelectHost {
    param (
        )
    $Hosts = @("pmx1.evorigin.com", "pmx2.evorigin.com", "pmx3.evorigin.com")
    $Found = $false
    while (-not $Found) {
        $RandomIndex = Get-Random -Maximum $Hosts.Count
        $Found = Test-Connection -ComputerName $Hosts[$RandomIndex] -Count 1 -Timeoutsecond 1 -Quiet
    }
    return $Hosts[$RandomIndex]
}

function Invoke-DfProxmoxRequest {
    param (
        [Parameter(Mandatory = $true)] [string]$ProxmoxServer,
        [Parameter(Mandatory = $true)] [string]$ProxmoxToken,
        [Parameter(Mandatory = $true)] [string]$Method,
        [Parameter(Mandatory = $true)] [string]$Body,
        [Parameter(Mandatory = $true)] [string]$Endpoint
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.add("Authorization", "$ProxmoxToken")
    if ($Method -eq "Get") {
        $headers.Add("Accept", "*/*")
        $headers.Add("Accept-Encoding", "gzip, deflate, br")
    }
    $ProxmoxURL = "https://" + $ProxmoxServer + ":8006"
    Invoke-RestMethod -Method $Method -Uri "$ProxmoxUrl$Endpoint" -Headers $headers -Body $Body -SkipHeaderValidation
}

function Invoke-DfProxmoxBalanceHosts {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $ProxmoxToken
    )

    # $ScriptPath = $PSScriptRoot
    # Set-Location $ScriptPath
    
    # $ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
    # $ScriptName = $MyInvocation.MyCommand.Name
    
    # $ErrorActionPreference = "SilentlyContinue"
    
    # if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
    # if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
    # if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
    $ProxmoxServer = Invoke-DfProxmoxSelectHost
    $balanced = $false

    while (!$balanced) {
        #Determine if cluster still needs balancing
        $response = Invoke-DfProxmoxRequest -ProxmoxServer $ProxmoxServer -ProxmoxToken $ProxmoxToken -Method "GET" -Endpoint "/api2/json/nodes"
        $ProxmoxNodes = $response.data
        $ProxmoxNodesSorted = $ProxmoxNodes | Sort-Object -Property mem

        $leastMemNode = $ProxmoxNodesSorted[0]
        $mostMemNode = $ProxmoxNodesSorted[-1]

        Write-Host "Least Memory Node: $($leastMemNode.node) with $([math]::Round($leastMemNode.mem / 1GB, 2)) GB used"
        Write-Host "Most Memory Node: $($mostMemNode.node) with $([math]::Round($mostMemNode.mem / 1GB, 2)) GB used"

        $Space1 = $mostMemNode.mem
        $Space2 = $leastMemNode.mem
        $Diff = $Space1 - $Space2
        if ($Diff -gt 4294967296) {
            #Get list of VMs on host with most memory used and pick a random VM
            $SourceVMs = (Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $ProxmoxToken -Method "GET" -Endpoint "/api2/json/nodes/$($mostMemNode.node)/qemu").data | Where-Object { $_.status -eq "running" }
            $RandomNumber = Get-Random -Maximum $($SourceVMs.Count)

            $VMtoMove = $SourceVMs[$RandomNumber]
        
            Write-Host "Migrating VM ID $($VMtoMove.vmid) from $($mostMemNode.node) to $($leastMemNode.node)."
            $migrateResponse = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $ProxmoxToken -Method "Post" -Endpoint "/api2/json/nodes/$($mostMemNode.node)/qemu/$($VMtoMove.vmid)/migrate?target=$($leastMemNode.node)&online=1"

            Write-Host "Waiting for migration task to complete."
            $migrationStatus = "notDone"
            while ($migrationStatus -eq "notDone") {
                Start-Sleep 5
                $taskResponse = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $ProxmoxToken -Method "Get" -Endpoint "/api2/json/nodes/$($mostMemNode.node)/tasks/$($migrateResponse.data)/status"
                if ( $taskResponse.data.status -eq "stopped" ) { $migrationStatus = "Done" }
            }

            if ($taskResponse.data.exitstatus -eq "OK") { Write-Host "VM migration completed successfully." }
            else { Write-Host "VM migration encountered a problem. Exit status: $($taskResponse.data.exitstatus)" -ForegroundColor Red; throw }

            Start-Sleep 5 
        }
        else {
            $balanced = $true
            Write-Host ("Exiting script. Cluster is balanced.")
        }
    }
}

function Invoke-DfProxmoxEvacuateHost {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][ValidateSet("pmx1", "pmx2", "pmx3")] [string] $HostToDrain,
        [Parameter(Mandatory = $true)] [string] $ProxmoxToken
    )
    $ProxmoxServer = Invoke-DfProxmoxSelectHost

    $VMsToMigrate = (Invoke-DfProxmoxRequest -ProxmoxServer $ProxmoxServer -ProxmoxToken $ProxmoxToken -Method "GET" -Endpoint "/api2/json/nodes/$HostToDrain/qemu").data | Where-Object { $_.status -eq "running" }
    $MigrationTargets = (Invoke-DfProxmoxRequest -ProxmoxServer $ProxmoxServer -ProxmoxToken $ProxmoxToken -Method "GET" -Endpoint "/api2/json/nodes").data | Where-Object { $_.node -ne $HostToDrain }

    foreach ($VM in $VMsToMigrate) {
        #Select target with most free memory
        $MigrationTargetsSorted = $MigrationTargets | Sort-Object -Property mem
        $TargetNode = $MigrationTargetsSorted[0]

        Write-Host "Migrating VM ID $($VM.vmid) from $HostToDrain to $($TargetNode.node)."
        $migrateResponse = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $ProxmoxToken -Method "Post" -Endpoint "/api2/json/nodes/$HostToDrain/qemu/$($VM.vmid)/migrate?target=$($TargetNode.node)&online=1"

        Write-Host "Waiting for migration task to complete."
        $migrationStatus = "notDone"
        while ($migrationStatus -eq "notDone") {
            Start-Sleep 5
            $taskResponse = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $ProxmoxToken -Method "Get" -Endpoint "/api2/json/nodes/$HostToDrain/tasks/$($migrateResponse.data)/status"
            if ( $taskResponse.data.status -eq "stopped" ) { $migrationStatus = "Done" }
        }

        if ($taskResponse.data.exitstatus -eq "OK") { Write-Host "VM migration completed successfully." }
        else { Write-Host "VM migration encountered a problem. Exit status: $($taskResponse.data.exitstatus)" -ForegroundColor Red; throw }

        Start-Sleep 5 
    }
}