# PeerLink List Android Devices and Emulators
# Queries ADB for connected physical devices/running emulators and lists configured AVDs.

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Available Devices & Emulators" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate adb
$adbExe = $null
$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if ($adbCmd) {
    $adbExe = $adbCmd.Source
} else {
    $localSdk = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Android\Sdk" } else { $null }
    if ($env:ANDROID_HOME -and (Test-Path (Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"))) {
        $adbExe = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
    } elseif ($env:ANDROID_SDK_ROOT -and (Test-Path (Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe"))) {
        $adbExe = Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe"
    } elseif ($localSdk -and (Test-Path (Join-Path $localSdk "platform-tools\adb.exe"))) {
        $adbExe = Join-Path $localSdk "platform-tools\adb.exe"
    }
}

# 2. Locate emulator
$emuExe = $null
$emuCmd = Get-Command emulator -ErrorAction SilentlyContinue
if ($emuCmd) {
    $emuExe = $emuCmd.Source
} else {
    $localSdk = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Android\Sdk" } else { $null }
    if ($env:ANDROID_HOME -and (Test-Path (Join-Path $env:ANDROID_HOME "emulator\emulator.exe"))) {
        $emuExe = Join-Path $env:ANDROID_HOME "emulator\emulator.exe"
    } elseif ($env:ANDROID_SDK_ROOT -and (Test-Path (Join-Path $env:ANDROID_SDK_ROOT "emulator\emulator.exe"))) {
        $emuExe = Join-Path $env:ANDROID_SDK_ROOT "emulator\emulator.exe"
    } elseif ($localSdk -and (Test-Path (Join-Path $localSdk "emulator\emulator.exe"))) {
        $emuExe = Join-Path $localSdk "emulator\emulator.exe"
    }
}

# 3. Query Connected Devices
Write-Host "`n--- Connected Android Devices & Running Emulators ---" -ForegroundColor Yellow
if ($adbExe) {
    $adbOutput = cmd.exe /c "`"$adbExe`" devices -l 2>&1"
    $lines = $adbOutput -split "`r?`n" | Where-Object { $_.Trim() -ne "" -and $_ -notmatch "^\* daemon" -and $_ -notmatch "^List of devices attached" }

    if ($lines.Count -gt 0) {
        foreach ($line in $lines) {
            Write-Host "  $line" -ForegroundColor Green
        }
    } else {
        Write-Host "  No devices or running emulators attached." -ForegroundColor Gray
    }
} else {
    Write-Host "  ADB executable not found. Unable to query devices." -ForegroundColor Red
}

# 4. Query Configured Virtual Devices (AVDs)
Write-Host "`n--- Configured Android Virtual Devices (AVDs) ---" -ForegroundColor Yellow
if ($emuExe) {
    $avdOutput = cmd.exe /c "`"$emuExe`" -list-avds 2>&1"
    $avds = $avdOutput -split "`r?`n" | Where-Object { $_.Trim() -ne "" }

    if ($avds.Count -gt 0) {
        foreach ($avd in $avds) {
            Write-Host "  [AVD] $avd" -ForegroundColor Green
        }
    } else {
        Write-Host "  No AVDs created. Create one in Android Studio Device Manager." -ForegroundColor Gray
    }
} else {
    Write-Host "  Emulator executable not found. Unable to list AVDs." -ForegroundColor Red
}

# 5. Query Flutter devices if available
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    Write-Host "`n--- Flutter Device Registry ---" -ForegroundColor Yellow
    & flutter devices
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
exit 0
