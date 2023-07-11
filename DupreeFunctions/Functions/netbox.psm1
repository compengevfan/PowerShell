Function Invoke-NetboxGetHeader {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [pscredential] $Credential
    )

    $NetboxApiToken = $Credential.GetNetworkCredential().Password

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", "application/json")
    $headers.Add("Authorization", "Token $NetboxApiToken")
    $headers.Add("Content-Type", "application/json")

    $headers
}

Function Invoke-NetboxAddVm {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $VMName,
        [Parameter()] [string] $Status = "active",
        [Parameter()] [int16] $Site = 1,
        [Parameter()] [int16] $Cluster = 1,
        [Parameter(Mandatory = $true)] [int16] $vCPUs,
        [Parameter(Mandatory = $true)] [int16] $RAM,
        [Parameter(Mandatory = $true)] [int16] $Disk,
        [Parameter(Mandatory = $true)] $header
    )

    # [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $Body = @{"name" = $VMName; "status" = $Status; "site" = $Site; "cluster" = $Cluster; "vcpus" = $vCPUs; "memory" = $($RAM * 1024); "disk" = $Disk }
    $BodyJSON = $Body | ConvertTo-JSON

    $response = Invoke-RestMethod 'https://jax-nbx001.evorigin.com/api/virtualization/virtual-machines/' -Method 'POST' -Headers $header -Body $BodyJSON
    $response | ConvertTo-Json
}

Function Invoke-NetboxAddVmInterface {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [int16] $VmId,
        [Parameter()] [string] $Name = "FrontEnd",
        [Parameter()] [string] $enabled = "true",
        [Parameter(Mandatory = $true)] $header
    )

    # [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $Body = @{ "virtual_machine" = $VmId; "name" = $Name; "enabled" = $enabled }
    $BodyJSON = $Body | ConvertTo-JSON

    $response = Invoke-RestMethod 'https://jax-nbx001.evorigin.com/api/virtualization/interfaces/' -Method 'POST' -Headers $header -Body $BodyJSON
    $response | ConvertTo-Json

}

Function Invoke-NetboxAddIp {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $IpAddress,
        [Parameter()] [string] $Status = "active",
        [Parameter()] [string] $AssignedObjectType = "virtualization.vminterface",
        [Parameter(Mandatory = $true)] [int16] $AssignedObjectId,
        [Parameter(Mandatory = $true)] [string] $DnsName,
        [Parameter(Mandatory = $true)] $header
    )

    # [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $Body = @{ "address" = $IpAddress; "status" = $Status; "assigned_object_type" = $AssignedObjectType; "assigned_object_id" = $AssignedObjectId; "dns_name" = $DnsName }
    $BodyJSON = $Body | ConvertTo-JSON

    $response = Invoke-RestMethod 'https://jax-nbx001.evorigin.com/api/ipam/ip-addresses/' -Method 'POST' -Headers $header -Body $BodyJSON
    $response | ConvertTo-Json

}

Function Invoke-NetboxAddIpToVM {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)] [string] $VmId,
        [Parameter(Mandatory = $true)] [int16] $IpId,
        [Parameter(Mandatory = $true)] $header
    )

    # [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $Body = @{ "primary_ip4" = $IpId }
    $BodyJSON = $Body | ConvertTo-JSON

    $response = Invoke-RestMethod "https://jax-nbx001.evorigin.com/api/virtualization/virtual-machines/$VmId/" -Method 'PATCH' -Headers $header -Body $BodyJSON
    $response | ConvertTo-Json

}
