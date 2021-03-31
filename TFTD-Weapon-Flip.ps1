if (Test-Path C:\Games\TFTD\GEODATA\OBDATA-Aliens.DAT)
{
    Write-Host "Setting Weapons for aliens..."
    Rename-Item -Path "C:\Games\TFTD\GEODATA\OBDATA.DAT" -NewName OBDATA-Me.DAT
    Rename-Item -Path "C:\Games\TFTD\GEODATA\OBDATA-Aliens.DAT" -NewName OBDATA.DAT
}
else
{
    Write-Host "Setting Weapons for me..."
    Rename-Item -Path "C:\Games\TFTD\GEODATA\OBDATA.DAT" -NewName OBDATA-Aliens.DAT
    Rename-Item -Path "C:\Games\TFTD\GEODATA\OBDATA-Me.DAT" -NewName OBDATA.DAT
}