#Get device info from VMax
function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}

Ignore-SSLCertificates
$Results = @()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12

#Get Devices from user input
function get-Devices{
    Write-Host "Enter devs seperated by commas" -ForegroundColor Yellow
    $volIDs = Read-Host "Enter devs"
    return $volIDs
}

#Get VMax
function get-VMax{
    $vmax
    $opt = 0
    Write-Host "Choose VMAX `r`n 1. EMC31 `r`n 2. EMC32 `r`n 3. EMC33 `r`n 4. EMC34 `r`n 5. EMC35 `r`n 6. EMC36"
    $opt = Read-Host "Selection"
    if($opt -eq "1"){
        $vmax = "https://tjaxp80307app:8443/univmax/restapi/provisioning/symmetrix/000195702517"
    }elseif($opt -eq "2"){
        $vmax = "https://tjaxp80307app:8443/univmax/restapi/provisioning/symmetrix/000195702384"
    }elseif($opt -eq "3"){
        $vmax = "https://tjaxp80307app:8443/univmax/restapi/sloprovisioning/symmetrix/000196701876"
    }elseif($opt -eq "4"){
        $vmax = "https://tjaxt80506app:8443/univmax/restapi/sloprovisioning/symmetrix/000197800605"
    }elseif($opt -eq "5"){
        $vmax = "https://tjaxt80506app:8443/univmax/restapi/sloprovisioning/symmetrix/000196801968"
    }elseif($opt -eq "6"){
        $vmax = "https://tjaxp80307app:8443/univmax/restapi/sloprovisioning/symmetrix/000197801744"
    }else{
        $vmax = get-VMax
    }
    return $vmax
}

function get-LunInfo{
    param([string]$devs,[string]$mv,[string]$baseURL, [System.Management.Automation.PSCredential] $cred)
    #$cred = Get-Credential
    $array = $devs.split(',')
    $cnt = $array.Count
    #gets hlu/alu
    $connections = $baseURL+'/maskingview/'+$mv+'/connections' 
    $api1 = Invoke-RestMethod -Credential $cred $connections
    #get wwns
    $volumes = $baseURL+'/volume/'
    $z = @()
    for($i = 0; $i -lt $cnt;$i++){
        $x = $array[$i].Length
        while($x -lt 5){
            $array[$i] = "0"+$array[$i]
        $x = $array[$i].Length
        }
    }
    foreach($x in $array){
        $x = $x.trim()
        $vols = $volumes + $x
        $api2 = Invoke-RestMethod -Credential $cred "$($volumes)$($x)"
        $wwn = $api2.volume.wwn
        $z += $api1.maskingviewconnection | where {$_.volumeID -eq $x} |select-object -unique @{l='ALU';e={$_.volumeID}},@{l='HLU';e={$_.host_lun_address}},@{l="WWN";e={$wwn}}        
    }
    $z.ForEach({[PSCustomObject]$_})|Format-Table -AutoSize    
}

function get-MaskingView{
    $mv = Read-Host "Enter Masking View"
    $mv = $mv.ToUpper()
    $mv = $mv.Trim()
    return $mv    
}

$user = $env:USERDOMAIN + '\' +$env:USERNAME
$enc = Get-Content 'H:\PowerShell Scripts\pscred.txt'|ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential($user,$enc)
$baseURL = get-VMax
$volId = get-Devices
$mask = get-MaskingView

get-LunInfo -devs $volId -baseURL $baseURL -mv $mask -cred $cred