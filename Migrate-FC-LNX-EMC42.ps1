[CmdletBinding()]
Param(
)

#requires -Version 3.0
# $DupreeFunctionsMinVersion = "1.0.2"

$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
  
$ScriptStarted = Get-Date -Format MM-dd-yyyy_HH-mm-ss
$ScriptName = $MyInvocation.MyCommand.Name
  
#$ErrorActionPreference = "SilentlyContinue"
  
# if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Write-Host "'DupreeFunctions' module not available!!! Please check with Dupree!!! Script exiting!!!" -ForegroundColor Red; exit }
# if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }

#Check if DupreeFunctions is installed and verify version
# if (!(Get-InstalledModule -Name DupreeFunctions -MinimumVersion $DupreeFunctionsMinVersion -ErrorAction SilentlyContinue))
# {
#     try 
#     {
#         if (!(Get-Module -ListAvailable -Name DupreeFunctions)) { Install-Module -Name DupreeFunctions -Scope CurrentUser -Force -ErrorAction Stop }
#         else { Update-Module -Name DupreeFunctions -RequiredVersion $DupreeFunctionsMinVersion -Force -ErrorAction Stop }
#     }
#     catch { Write-Host "Failed to install 'DupreeFunctions' module from PSGallery!!! Error encountered is:`n`r`t$($Error[0])`n`rScript exiting!!!" -ForegroundColor Red ; exit }
# }

if (!(Get-Module -Name DupreeFunctions)) { Import-Module DupreeFunctions }
if (!(Test-Path .\~Logs)) { New-Item -Name "~Logs" -ItemType Directory | Out-Null }
else { Get-ChildItem .\~Logs | Where-Object CreationTime -LT (Get-Date).AddDays(-30) | Remove-Item }
  
Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Script Started..."

$ServerName1 = Read-Host "First Server Name?"
$ServerName2 = Read-Host "Second Server Name?"
$ServerName2Fragment = $ServerName2.Substring($ServerName2.Length -2)
$Server1WWNASide = Read-Host "Server 1 A-side WWN?"
$Server1WWNASideNoColon = $Server1WWNASide.Replace(":","")
$Server1WWNBSide = Read-Host "Server 1 B-side WWN?"
$Server1WWNBSideNoColon = $Server1WWNBSide.Replace(":","")
$Server2WWNASide = Read-Host "Server 2 A-side WWN?"
$Server2WWNASideNoColon = $Server2WWNASide.Replace(":","")
$Server2WWNBSide = Read-Host "Server 2 B-side WWN?"
$Server2WWNBSideNoColon = $Server2WWNBSide.Replace(":","")
$Port1A = Read-Host "First A-side Array Port?"
$Port2A = Read-Host "Second A-side Array Port?"
$Port1B = Read-Host "First B-side Array Port?"
$Port2B = Read-Host "Second B-side Array Port?"
$DeviceCapacity = Read-Host "Device Size"
$CapType = Read-Host "Capacity Type? (gb or tb)"
$DeviceCount = Read-Host "How Many Devices?"
$ChangeNumber = Read-Host "What is the CC?"
Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Saving Variable Information..."

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Reading template file..."
$TemplateText = Get-Content -path .\Migrate-FC-LNX-EMC42-Template.txt -Raw

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Performing text replacement..."
$TemplateText.Replace("[Server Name1]",$ServerName1)
$TemplateText.Replace("[Server Name2]",$ServerName2)
$TemplateText.Replace("[Server Name2 Fragment]",$ServerName2Fragment)
$TemplateText.Replace("[Server1WWN-A-Side]",$Server1WWNASide)
$TemplateText.Replace("[Server1WWN-A-Side no :]",$Server1WWNASideNoColon)
$TemplateText.Replace("[Server1WWN-B-Side]",$Server1WWNBSide)
$TemplateText.Replace("[Server1WWN-B-Side no :]",$Server1WWNBSideNoColon)
$TemplateText.Replace("[Server2WWN-A-Side]",$Server2WWNASide)
$TemplateText.Replace("[Server2WWN-A-Side no :]",$Server2WWNASideNoColon)
$TemplateText.Replace("[Server2WWN-B-Side]",$Server2WWNBSide)
$TemplateText.Replace("[Server2WWN-B-Side no :]",$Server2WWNBSideNoColon)
$TemplateText.Replace("[Port1A]",$Port1A)
$TemplateText.Replace("[Port2A]",$Port2A)
$TemplateText.Replace("[Port1B]",$Port1B)
$TemplateText.Replace("[Port2B]",$Port2B)
$TemplateText.Replace("[device capacity]",$DeviceCapacity)
$TemplateText.Replace("[cap type]",$CapType)
$TemplateText.Replace("[device count]",$DeviceCount)

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Info -LogString "Writing Command file..."
$FileName = $ChangeNumber + "-EMC42-" + $ServerName1 + "Zone and create storage"
Set-Content "C:\Users\y7537\OneDrive - CSX\Documents\CLI\WorkingDir\EMC42 Migration\$FileName.txt"

Invoke-Logging -ScriptStarted $ScriptStarted -ScriptName $ScriptName -LogType Succ -LogString "Script Completed Succesfully."