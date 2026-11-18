# PeerLink 1-Click Windows User-Level Installer
# Installs PeerLink to %LocalAppData%\Programs\PeerLink without requiring Administrator privileges.
# Sets up Desktop Shortcut, Start Menu Shortcut, and File Explorer Context Menu.

param(
    [switch]$StartOnBoot,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$distDir = if (Test-Path "$scriptDir\bin\peerlink.exe") { $scriptDir } else { (Split-Path -Parent $scriptDir) }
$binExe = "$distDir\bin\peerlink.exe"

if (-not (Test-Path $binExe)) {
    # If running from repo scripts folder, locate distribution
    $candidate = "C:\Users\OMEN\.gemini\antigravity-ide\scratch\peerlink-master\windows\dist\peerlink-windows-1.0.0-rc1"
    if (Test-Path "$candidate\bin\peerlink.exe") {
        $distDir = $candidate
        $binExe = "$candidate\bin\peerlink.exe"
    } else {
        Write-Error "Cannot install: peerlink.exe not found. Please build or unpack release first."
        exit 1
    }
}

$installDir = "$env:LOCALAPPDATA\Programs\PeerLink"
$desktopDir = [System.Environment]::GetFolderPath('Desktop')
$startMenuDir = [System.Environment]::GetFolderPath('Programs')

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Automated 1-Click Installer (Windows x64)" -ForegroundColor Cyan
Write-Host " Install Target: $installDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Close running instances if any
Write-Host "`n[1/5] Checking for running instances..." -ForegroundColor Cyan
$running = Get-Process -Name "peerlink" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "Closing running PeerLink instance..." -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Milliseconds 800
}

# 2. Copy program files
Write-Host "[2/5] Installing application files..." -ForegroundColor Cyan
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

Copy-Item -Path "$distDir\*" -Destination $installDir -Recurse -Force

$installedExe = "$installDir\bin\peerlink.exe"
$workingDir = "$installDir\bin"

# 3. Create Desktop & Start Menu Shortcuts
Write-Host "[3/5] Creating Desktop and Start Menu shortcuts..." -ForegroundColor Cyan
$wshShell = New-Object -ComObject WScript.Shell

# Desktop Shortcut
$desktopShortcutPath = Join-Path $desktopDir "PeerLink.lnk"
$desktopShortcut = $wshShell.CreateShortcut($desktopShortcutPath)
$desktopShortcut.TargetPath = $installedExe
$desktopShortcut.WorkingDirectory = $workingDir
$desktopShortcut.Description = "PeerLink - Private P2P Local Data Network"
$desktopShortcut.Save()

# Start Menu Shortcut
$startMenuShortcutPath = Join-Path $startMenuDir "PeerLink.lnk"
$startMenuShortcut = $wshShell.CreateShortcut($startMenuShortcutPath)
$startMenuShortcut.TargetPath = $installedExe
$startMenuShortcut.WorkingDirectory = $workingDir
$startMenuShortcut.Description = "PeerLink - Private P2P Local Data Network"
$startMenuShortcut.Save()

# 4. Register Windows Explorer Context Menu
Write-Host "[4/5] Registering Explorer right-click context menu..." -ForegroundColor Cyan
$cmdFile = "HKCU:\Software\Classes\*\shell\PeerLink\command"
$cmdDir = "HKCU:\Software\Classes\Directory\shell\PeerLink\command"

New-Item -Path "HKCU:\Software\Classes\*\shell\PeerLink" -Value "Send with PeerLink" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Classes\*\shell\PeerLink" -Name "Icon" -Value "`"$installedExe`"" -PropertyType String -Force | Out-Null
New-Item -Path $cmdFile -Value "`"$installedExe`" `"%1`"" -Force | Out-Null

New-Item -Path "HKCU:\Software\Classes\Directory\shell\PeerLink" -Value "Send folder with PeerLink" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\PeerLink" -Name "Icon" -Value "`"$installedExe`"" -PropertyType String -Force | Out-Null
New-Item -Path $cmdDir -Value "`"$installedExe`" `"%1`"" -Force | Out-Null

# 5. Optional Start on Boot
if ($StartOnBoot) {
    Write-Host "Configuring automatic start on Windows boot..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "PeerLink" -Value "`"$installedExe`"" -Force
}

# 6. Generate Uninstaller
$uninstallScript = @"
@echo off
echo Uninstalling PeerLink...
taskkill /F /IM peerlink.exe 2>nul
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "
Remove-Item -Path '$desktopShortcutPath' -Force -ErrorAction SilentlyContinue;
Remove-Item -Path '$startMenuShortcutPath' -Force -ErrorAction SilentlyContinue;
Remove-Item -Path 'HKCU:\Software\Classes\*\shell\PeerLink' -Recurse -Force -ErrorAction SilentlyContinue;
Remove-Item -Path 'HKCU:\Software\Classes\Directory\shell\PeerLink' -Recurse -Force -ErrorAction SilentlyContinue;
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'PeerLink' -ErrorAction SilentlyContinue;
"
echo PeerLink shortcuts and context menu removed.
echo To delete program files, close this window and delete: $installDir
pause
"@
Set-Content -Path "$installDir\uninstall.bat" -Value $uninstallScript -Encoding Ascii

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " PeerLink Installation Complete!" -ForegroundColor Green
Write-Host " Desktop Shortcut   : $desktopShortcutPath" -ForegroundColor Green
Write-Host " Start Menu Shortcut: $startMenuShortcutPath" -ForegroundColor Green
Write-Host " Context Menu       : Right-click any file -> Send with PeerLink" -ForegroundColor Green
Write-Host " Uninstaller        : $installDir\uninstall.bat" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
