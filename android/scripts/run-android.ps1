# PeerLink Android Run on Device/Emulator Script
# Launches the application on a connected device or Android Virtual Device.

param (
    [string]$DeviceId = "",
    [switch]$Release = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$androidDir = Split-Path -Parent $scriptDir
$flutterDir = Join-Path $androidDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Application Runner" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Check Flutter SDK
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Host "BLOCKED: Flutter SDK is not installed on PATH." -ForegroundColor Red
    Write-Host "         Cannot deploy or hot-reload Flutter Android app without Flutter toolchain." -ForegroundColor Yellow
    Write-Host "         To run native Android APK directly via ADB:" -ForegroundColor Yellow
    Write-Host "           adb install -r <path-to-apk>" -ForegroundColor Gray
    Write-Host "           adb shell am start -n org.peerlink.peerlink/.MainActivity" -ForegroundColor Gray
    exit 1
}

# Check target device
if (-not $DeviceId) {
    Write-Host "No DeviceId provided. Querying available devices..." -ForegroundColor Gray
    $devices = (& flutter devices 2>&1) | Out-String
    Write-Host $devices

    Write-Host "Please specify a target device using: -DeviceId <device_id>" -ForegroundColor Yellow
    exit 1
}

try {
    Push-Location $flutterDir
    $mode = if ($Release) { "--release" } else { "--debug" }
    Write-Host "Executing: flutter run -d $DeviceId $mode in $flutterDir..." -ForegroundColor Cyan
    & flutter run -d $DeviceId $mode
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
