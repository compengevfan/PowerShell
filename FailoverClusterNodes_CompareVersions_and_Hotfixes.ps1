### SCRIPT PARAMETERS ###
## $SqlServerName : the clustered instance name as input ##
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [String]$SqlServerName
)
### END SCRIPT PARAMETERS ###


<#
    Function: 
        Compare-SqlVersion
    Description:
        
#>
Function Compare-SqlVersion {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$Server1,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Server2,

        [Parameter(Mandatory = $true, Position = 2)]
        [String]$SqlServerName,

        [Parameter(Mandatory = $true, Position = 3)]
        [Int32]$SqlVersion,

        [Parameter(Mandatory = $true, Position = 4)]
        [String]$SqlServiceName
    )

    if ($SqlVersion -eq 9) {
        $SqlVersion = ""
    }
    
    $Server1Version = Get-WmiObject -ComputerName $Server1 -Class SqlServiceAdvancedProperty -Namespace "root\Microsoft\SqlServer\ComputerManagement$SqlVersion" |
        Where-Object {$_.SqlServiceType -eq 1 -and $_.PropertyName -eq "FILEVERSION" -and $_.ServiceName -eq $SqlServiceName} |
        Select-Object -ExpandProperty PropertyStrValue

    $Server2Version = Get-WmiObject -ComputerName $Server2 -Class SqlServiceAdvancedProperty -Namespace "root\Microsoft\SqlServer\ComputerManagement$SqlVersion" |
        Where-Object {$_.SqlServiceType -eq 1 -and $_.PropertyName -eq "FILEVERSION" -and $_.ServiceName -eq $SqlServiceName} |
        Select-Object -ExpandProperty PropertyStrValue

    if (!$Server1Version -or !$Server2Version) {
        return "NonexistentSql"
    }
        
    Compare-Object $Server1Version $Server2Version |
        Select-Object @{Name = "InstanceName"; Expression = {$SqlServerName}},
            @{Name = "OwningNode"; Expression = {
                if ($_.SideIndicator -eq "<=") {
                    $Server1
                }
                elseif ($_.SideIndicator -eq "=>") {
                    $Server2
                }
            }},
            @{Name = "Issue"; Expression = {"SqlVersionMismatch"}},
            @{Name = "Discrepancy"; Expression = {$_.InputObject}}
}

Function Compare-OsVersion {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$Server1,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Server2,

        [Parameter(Mandatory = $true, Position = 2)]
        [String]$SqlServerName
    )

    Compare-Object (Get-WmiObject -ComputerName $Server1 -Class Win32_OperatingSystem | Select-Object -ExpandProperty Version) (Get-WmiObject -ComputerName $Server2 -Class Win32_OperatingSystem | Select-Object -ExpandProperty Version) |
        Select-Object @{Name = "InstanceName"; Expression = {$SqlServerName}},
            @{Name = "OwningNode"; Expression = {
                if ($_.SideIndicator -eq "<=") {
                    $Server1
                }
                elseif ($_.SideIndicator -eq "=>") {
                    $Server2
                }
            }},
            @{Name = "Issue"; Expression = {"OsVersionMismatch"}},
            @{Name = "Discrepancy"; Expression = {$_.InputObject}}


    $Server1HotFix = Get-HotFix -ComputerName $Server1 | 
        Select-Object -ExpandProperty HotFixID
    $Server2HotFix = Get-HotFix -ComputerName $Server2 | 
        Select-Object -ExpandProperty HotFixID

    if (!$Server1HotFix) {
        $Server1HotFix = ""
    }
    if (!$Server2HotFix) {
        $Server2HotFix = ""
    }

    Compare-Object $Server1HotFix $Server2HotFix |
            Select-Object @{Name = "InstanceName"; Expression = {$SqlServerName}},
                @{Name = "OwningNode"; Expression = {
                    if ($_.SideIndicator -eq "<=") {
                        $Server2
                    }
                    elseif ($_.SideIndicator -eq "=>") {
                        $Server1
                    }
                }},
                @{Name = "Issue"; Expression = {"OsHotfixMissing"}},
                @{Name = "Discrepancy"; Expression = {$_.InputObject}} |
            Where-Object {$_.Discrepancy -ne ""}
}


[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") |
    Out-Null

#$IssuesResults = @()
$SqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($SqlServerName)


if ($SqlServer.InstanceName -eq "") {
    $SqlServiceName = "MSSQLSERVER"
}
else {
    $SqlServiceName = 'MSSQL$' + $SqlServer.InstanceName
}

if ($SqlServer.IsClustered) {
    $SqlNodesStats = $SqlServer.Databases["master"].ExecuteWithResults("select NodeName from sys.dm_os_cluster_nodes;").Tables[0] |
        Select-Object -ExpandProperty NodeName  
          
       
    $IssuesResults = for ($i = 0; $i -lt ($SqlNodesStats.Count - 1); $i++) {
        for ($j = 0; $j -lt $SqlNodesStats.Count; $j++) {
            if ($i -ne $j) {
                $SqlVersionReturn = Compare-SqlVersion -Server1 $SqlNodesStats[$i] -Server2 $SqlNodesStats[$j] -SqlServerName $SqlServerName -SqlVersion $SqlServer.VersionMajor -SqlServiceName $SqlServiceName
                if ($SqlVersionReturn -ne "NonexistentSql") {
                    $SqlVersionReturn
                    Compare-OsVersion -Server1 $SqlNodesStats[$i] -Server2 $SqlNodesStats[$j] -SqlServerName $SqlServerName
                }
            }
        }
    }

    $IssuesResults |
        Sort-Object -Property InstanceName, Issue, OwningNode, Discrepancy -Unique

    if (!$IssuesResults) {
        Write-Host "No identified version/hotfix mismatches"
    }
}
else {
    Write-Host "$($SqlServer.Name) is not a clustered instance"
}