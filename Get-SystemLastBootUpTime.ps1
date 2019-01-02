<#   
.SYNOPSIS   
    This script gets a system last boot up time.   
.DESCRIPTION   
    This script uses WMI to get a system last boot up time. 
.INPUTS 
    You can enter a list of computernames as a parameter. 
    The defaut is the current computer. 
    The script accepts input from the pipeline. 
.OUTPUTS 
    An object containing Computer and LastBootUpTime properties. 
.NOTES   
    File Name  : Get-SystemLastBootUpTime.ps1   
    Author     : Robert van den Nieuwendijk 
    Twitter    : rvdnieuwendijk 
    Requires   : PowerShell Version 2.0   
.LINK   
    This script is posted to Microsoft TechNet Script Center Repository:   
    http://gallery.technet.microsoft.com/ScriptCenter/en-us/  
.EXAMPLE   
    C:\PS>.\Get-SystemLastBootUpTime.ps1   
    Retrieves the last boot up time from the current system. 
.EXAMPLE   
    C:\PS>.\Get-SystemLastBootUpTime.ps1 -ComputerName server1,server2 
    Retrieves the last boot up time from server1 and server 2. 
.EXAMPLE   
    C:\PS>"server1","server2"| .\Get-SystemLastBootUpTime.ps1 
    Retrieves the last boot up time from server1 and server 2.     
#>  
 
param ([Parameter(ValueFromPipeline=$true)][string[]] $ComputerName = '.') 
 
begin { 
    function Get-SystemLastBootUpTimeForOneSystem { 
        param ([string] $ComputerName = '.') 
        $Report = "" | Select-Object -property Computer,LastBootUpTime 
        $Report.Computer = $ComputerName 
        $LastBootUpTime = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName).LastBootUpTime
        $Report.LastBootUpTime = [datetime]::ParseExact($LastBootUpTime.split(".")[0],'yyyyMMddHHmmss',$null)
        $Report 
    } 
} 
 
process { 
    if ($ComputerName -is [array]) { 
        $ComputerNames = $ComputerName 
        foreach ($ComputerName in $ComputerNames) { 
            Get-SystemLastBootUpTimeForOneSystem -ComputerName $ComputerName 
        } 
    } 
    else { 
        Get-SystemLastBootUpTimeForOneSystem -ComputerName $ComputerName 
    } 
} 
