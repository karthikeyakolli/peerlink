# PeerLink Android Environment & Prerequisites Checker
# Inspects the host machine for Android Studio, Android SDK, NDK, ADB, and Flutter.

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Environment & Prerequisites Check" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$report = @()
$hasFatal = $false

# 1. Java Runtime (JDK 17 or 21 required for Android Gradle Plugin)
$javaFound = $false
$javaVersion = "Missing"
try {
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) {
        $output = (& java -version 2>&1) | Out-String
        if ($output -match 'version "([^"]+)"') {
            $javaVersion = $matches[1]
            $javaFound = $true
        } else {
            $javaVersion = "Detected (" + $javaCmd.Source + ")"
            $javaFound = $true
        }
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "Java Runtime (JDK)"
    Required  = "JDK 17 or 21"
    Found     = if ($javaFound) { "INSTALLED" } else { "MISSING" }
    Details   = $javaVersion
}
if (-not $javaFound) { $hasFatal = $true }

# 2. Android SDK (ANDROID_HOME / ANDROID_SDK_ROOT / %LOCALAPPDATA%\Android\Sdk)
$sdkFound = $false
$sdkPath = "Missing"
$candidateSdkPaths = @()
if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) { $candidateSdkPaths += $env:ANDROID_HOME }
if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) { $candidateSdkPaths += $env:ANDROID_SDK_ROOT }
$localSdk = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Android\Sdk" } else { $null }
if ($localSdk -and (Test-Path $localSdk)) { $candidateSdkPaths += $localSdk }

if ($candidateSdkPaths.Count -gt 0) {
    $sdkFound = $true
    $sdkPath = $candidateSdkPaths[0]
}

$report += [PSCustomObject]@{
    Component = "Android SDK"
    Required  = "API 34 / 35 (Android 14/15)"
    Found     = if ($sdkFound) { "INSTALLED" } else { "MISSING" }
    Details   = $sdkPath
}

# 3. Android Studio IDE
$studioFound = $false
$studioDetails = "Missing"
$candidateStudio = @()
$studioDefault1 = "C:\Program Files\Android\Android Studio\bin\studio64.exe"
$studioDefault2 = "C:\Program Files\Android\Android Studio\bin\studio.exe"
$localStudio = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Programs\Android Studio\bin\studio64.exe" } else { $null }

if (Test-Path $studioDefault1) { $candidateStudio += $studioDefault1 }
if (Test-Path $studioDefault2) { $candidateStudio += $studioDefault2 }
if ($localStudio -and (Test-Path $localStudio)) { $candidateStudio += $localStudio }

if ($candidateStudio.Count -gt 0) {
    $studioFound = $true
    $studioDetails = $candidateStudio[0]
} else {
    $studioCmd = Get-Command studio64 -ErrorAction SilentlyContinue
    if ($studioCmd) {
        $studioFound = $true
        $studioDetails = $studioCmd.Source
    }
}

$report += [PSCustomObject]@{
    Component = "Android Studio IDE"
    Required  = "Hedgehog / Iguana / Jellyfish / Koala"
    Found     = if ($studioFound) { "INSTALLED" } else { "MISSING" }
    Details   = $studioDetails
}

# 4. Android Debug Bridge (adb)
$adbFound = $false
$adbDetails = "Missing"
$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if ($adbCmd) {
    $adbFound = $true
    $adbDetails = $adbCmd.Source
} elseif ($sdkFound) {
    $candidateAdb = Join-Path $sdkPath "platform-tools\adb.exe"
    if (Test-Path $candidateAdb) {
        $adbFound = $true
        $adbDetails = $candidateAdb
    }
}

$report += [PSCustomObject]@{
    Component = "Android Debug Bridge (adb)"
    Required  = "platform-tools 34+"
    Found     = if ($adbFound) { "INSTALLED" } else { "MISSING" }
    Details   = $adbDetails
}

# 5. Android Emulator (emulator)
$emuFound = $false
$emuDetails = "Missing"
$emuCmd = Get-Command emulator -ErrorAction SilentlyContinue
if ($emuCmd) {
    $emuFound = $true
    $emuDetails = $emuCmd.Source
} elseif ($sdkFound) {
    $candidateEmu = Join-Path $sdkPath "emulator\emulator.exe"
    if (Test-Path $candidateEmu) {
        $emuFound = $true
        $emuDetails = $candidateEmu
    }
}

$report += [PSCustomObject]@{
    Component = "Android Emulator"
    Required  = "AVD manager & hypervisor"
    Found     = if ($emuFound) { "INSTALLED" } else { "MISSING" }
    Details   = $emuDetails
}

# 6. Flutter SDK
$flutterFound = $false
$flutterDetails = "Missing"
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    $flutterFound = $true
    $output = cmd.exe /c "flutter --version 2>&1"
    if ($output -match 'Flutter ([^\s]+)') {
        $flutterDetails = "v" + $matches[1]
    } else {
        $flutterDetails = $flutterCmd.Source
    }
}

$report += [PSCustomObject]@{
    Component = "Flutter SDK"
    Required  = "3.24.0+ (stable)"
    Found     = if ($flutterFound) { "INSTALLED" } else { "MISSING" }
    Details   = $flutterDetails
}

# 7. Gradle CLI
$gradleFound = $false
$gradleDetails = "Missing"
$gradleCmd = Get-Command gradle -ErrorAction SilentlyContinue
if ($gradleCmd) {
    $gradleFound = $true
    $gradleDetails = $gradleCmd.Source
}

$report += [PSCustomObject]@{
    Component = "Gradle Build Tool"
    Required  = "Gradle 8.5+ (or gradlew wrapper)"
    Found     = if ($gradleFound) { "INSTALLED" } else { "MISSING (wrapper provided)" }
    Details   = $gradleDetails
}

# Format Output Table
Write-Host ""
$report | Format-Table -AutoSize -Property Component, Required, Found, Details

Write-Host "==========================================================" -ForegroundColor Cyan
if ($hasFatal) {
    Write-Host "FATAL: Java runtime is NOT available." -ForegroundColor Red
    exit 1
} elseif (-not $sdkFound -or -not $flutterFound) {
    Write-Host "STATUS: Android compilation / device execution is BLOCKED." -ForegroundColor Yellow
    if (-not $sdkFound) {
        Write-Host "  -> Android SDK missing: Install via Android Studio or commandlinetools" -ForegroundColor Yellow
    }
    if (-not $flutterFound) {
        Write-Host "  -> Flutter SDK missing: Download from https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host "STATUS: All prerequisites are met! Android builds enabled." -ForegroundColor Green
    exit 0
}
