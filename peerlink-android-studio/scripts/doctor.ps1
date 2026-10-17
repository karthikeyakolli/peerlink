<#
.SYNOPSIS
    Reports detected toolchains and prerequisites for PeerLink Android Studio Edition.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Studio Edition - Environment Doctor       " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$allPass = $true

# 1. Flutter
Write-Host "`n[1/6] Checking Flutter & Dart SDK..." -ForegroundColor Yellow
try {
    $flutterVer = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] $flutterVer" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Flutter not found in PATH." -ForegroundColor Red
    $allPass = $false
}

# 2. Java / JDK
Write-Host "`n[2/6] Checking Java Runtime..." -ForegroundColor Yellow
try {
    $javaVer = java -version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] $javaVer" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Java not found in PATH." -ForegroundColor Red
    $allPass = $false
}

# 3. Android SDK
Write-Host "`n[3/6] Checking Android SDK..." -ForegroundColor Yellow
$sdkPath = $env:ANDROID_HOME
if (-not $sdkPath) { $sdkPath = $env:ANDROID_SDK_ROOT }
if (-not $sdkPath) { $sdkPath = "$env:LOCALAPPDATA\Android\Sdk" }

if (Test-Path $sdkPath) {
    Write-Host "  [OK] Android SDK located at: $sdkPath" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Android SDK not found at $sdkPath" -ForegroundColor Red
    $allPass = $false
}

# 4. ADB
Write-Host "`n[4/6] Checking ADB (Android Debug Bridge)..." -ForegroundColor Yellow
$adbPath = "$sdkPath\platform-tools\adb.exe"
if (Test-Path $adbPath) {
    $adbVer = & $adbPath version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] $adbVer" -ForegroundColor Green
} else {
    Write-Host "  [WARN] adb.exe not found at $adbPath" -ForegroundColor Yellow
}

# 5. Connected Devices & Emulators
Write-Host "`n[5/6] Checking Connected Devices & Emulators..." -ForegroundColor Yellow
if (Test-Path $adbPath) {
    $devices = & $adbPath devices 2>&1 | Where-Object { $_ -match "\tdevice$" }
    if ($devices) {
        $devices | ForEach-Object { Write-Host "  [DEVICE] $_" -ForegroundColor Green }
    } else {
        Write-Host "  [INFO] No physical devices connected." -ForegroundColor Gray
    }
}

$emuPath = "$sdkPath\emulator\emulator.exe"
if (Test-Path $emuPath) {
    $avds = & $emuPath -list-avds 2>&1
    if ($avds) {
        Write-Host "  [AVD Available] $($avds -join ', ')" -ForegroundColor Green
    }
}

# 6. Android Studio
Write-Host "`n[6/6] Checking Android Studio Installation..." -ForegroundColor Yellow
$studioPaths = @(
    "C:\Program Files\Android\Android Studio\bin\studio64.exe",
    "$env:LOCALAPPDATA\Programs\Android Studio\bin\studio64.exe"
)
$studioFound = $false
foreach ($p in $studioPaths) {
    if (Test-Path $p) {
        Write-Host "  [OK] Android Studio launcher found: $p" -ForegroundColor Green
        $studioFound = $true
        break
    }
}
if (-not $studioFound) {
    Write-Host "  [INFO] Android Studio executable not found in default locations." -ForegroundColor Gray
}

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($allPass) {
    Write-Host " Doctor Result: ALL PREREQUISITES READY (PASS)" -ForegroundColor Green
    exit 0
} else {
    Write-Host " Doctor Result: SOME PREREQUISITES MISSING (WARN/FAIL)" -ForegroundColor Yellow
    exit 1
}
