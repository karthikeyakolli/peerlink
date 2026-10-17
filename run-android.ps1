# PeerLink Android One-Click Launcher
[CmdletBinding()]
param(
    [string]$DeviceId,
    [switch]$BuildOnly
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
Set-Location $repoRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  PeerLink Android - One-Click Launcher" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$androidDir = Join-Path $repoRoot "peerlink-android-studio"
if (-not (Test-Path $androidDir)) {
    Write-Error "Could not find peerlink-android-studio at $androidDir"
}

# 1. Check Flutter
$flutterBin = "flutter"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter SDK not found in PATH."
}

# 2. Check Devices / ADB
$adbBin = "adb"
$hasAdb = Get-Command adb -ErrorAction SilentlyContinue

if ($BuildOnly) {
    Write-Host "Compiling Android Debug APK..." -ForegroundColor Yellow
    Push-Location (Join-Path $androidDir "android")
    .\gradlew.bat assembleDebug
    Pop-Location
    Write-Host "Build complete!" -ForegroundColor Green
    exit 0
}

Write-Host "Checking connected Android devices..." -ForegroundColor Yellow
if ($hasAdb) {
    $devicesOutput = & adb devices | Out-String
    $onlineDevices = $devicesOutput -split "`r?`n" | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices" }
    
    if (-not $onlineDevices) {
        Write-Host "No active Android device found. Checking local emulators..." -ForegroundColor Yellow
        $avds = & emulator -list-avds 2>$null
        if ($avds) {
            $targetAvd = $avds[0]
            Write-Host "Booting Android emulator '$targetAvd'..." -ForegroundColor Cyan
            Start-Process -FilePath "emulator" -ArgumentList "-avd", $targetAvd, "-no-snapshot-load" -WindowStyle Minimized
            Write-Host "Waiting for device to finish booting..." -ForegroundColor Yellow
            & adb wait-for-device
            Write-Host "Device ready!" -ForegroundColor Green
        }
    }
}

Write-Host "Launching PeerLink Android App..." -ForegroundColor Cyan
Push-Location $androidDir
if ($DeviceId) {
    & $flutterBin run -d $DeviceId
} else {
    & $flutterBin run
}
Pop-Location
