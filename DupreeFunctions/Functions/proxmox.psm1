function Invoke-DfProxmoxRequest {
    param (
        [Parameter(Mandatory = $true)] [string]$ProxmoxServer,
        [Parameter(Mandatory = $true)] [string]$ProxmoxToken,
        [Parameter(Mandatory = $true)] [string]$Method,
        [Parameter(Mandatory = $true)] [string]$Endpoint
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.add("Authorization", "$ProxmoxToken")
    if ($Method -eq "Get") {
        $headers.Add("Accept", "*/*")
        $headers.Add("Accept-Encoding", "gzip, deflate, br")
    }
    $ProxmoxURL = "https://" + $ProxmoxServer + ":8006"
    Invoke-RestMethod -Method $Method -Uri "$ProxmoxUrl$Endpoint" -Headers $headers -SkipHeaderValidation
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

    #Determine if cluster needs balancing
    $clusterResponse = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $ProxmoxToken -Method "GET" -Endpoint "/api2/json/nodes"
    $ProxmoxNodes = $clusterResponse.data
    $ProxmoxNodesSorted = $ProxmoxNodes | Sort-Object -Property mem

    $leastMemNode = $ProxmoxNodesSorted[0]
    $mostMemNode = $ProxmoxNodesSorted[-1]

    Write-Host "Least Memory Node: $($leastMemNode.node) with $([math]::Round($leastMemNode.mem / 1GB, 2)) GB used"
    Write-Host "Most Memory Node: $($mostMemNode.node) with $([math]::Round($mostMemNode.mem / 1GB, 2)) GB used"

    $Space1 = $mostMemNode.mem
    $Space2 = $leastMemNode.mem
    $Diff = $Space1 - $Space2
    if ($Diff -gt 4294967296) { $RunAgain = $true }
    else {
        $RunAgain = $false
        Write-Host ("Exiting script. Cluster is balanced.")
    }

    while ($RunAgain) {
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

        #Determine if cluster still needs balancing
        $response = Invoke-DfProxmoxRequest -ProxmoxServer "pmx1.evorigin.com" -ProxmoxToken $ProxmoxToken -Method "GET" -Endpoint "/api2/json/nodes"
        $ProxmoxNodes = $response.data
        $ProxmoxNodesSorted = $ProxmoxNodes | Sort-Object -Property mem

        $leastMemNode = $ProxmoxNodesSorted[0]
        $mostMemNode = $ProxmoxNodesSorted[-1]

        Write-Host "Least Memory Node: $($leastMemNode.node) with $([math]::Round($leastMemNode.mem / 1GB, 2)) GB used"
        Write-Host "Most Memory Node: $($mostMemNode.node) with $([math]::Round($mostMemNode.mem / 1GB, 2)) GB used"

        $Space1 = $mostMemNode.mem
        $Space2 = $leastMemNode.mem
        $Diff = $Space1 - $Space2
        if ($Diff -gt 4294967296) { $RunAgain = $true }
        else {
            $RunAgain = $false
            Write-Host ("Exiting script. Cluster is balanced.")
        }
        # $RunAgain = $false
    }
}

function Invoke-DfProxmoxEvacuateHost {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $ProxmoxToken
    )

    
}