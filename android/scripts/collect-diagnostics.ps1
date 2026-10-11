# PeerLink Android System & Environment Diagnostics Script
# Gathers Android SDK details, build-tools, connected devices, and logs.

param (
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot
$androidDir = Split-Path -Parent $scriptDir
$diagOutput = [System.Text.StringBuilder]::new()

function Write-Diag([string]$text, [string]$color = "White") {
    Write-Host $text -ForegroundColor $color
    [void]$diagOutput.AppendLine($text)
}

Write-Diag "==========================================================" "Cyan"
Write-Diag " PeerLink Android System & Runtime Diagnostics" "Cyan"
Write-Diag " Timestamp: $([DateTime]::UtcNow.ToString('o'))" "Cyan"
Write-Diag "==========================================================" "Cyan"

# 1. Operating System Details
Write-Diag "`n--- 1. Operating System ---" "Yellow"
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($os) {
    Write-Diag "OS Caption:      $($os.Caption)" "Gray"
    Write-Diag "OS Version:      $($os.Version) (Build $($os.BuildNumber))" "Gray"
    Write-Diag "Architecture:    $($os.OSArchitecture)" "Gray"
}

# 2. Java Environment
Write-Diag "`n--- 2. Java Environment ---" "Yellow"
Write-Diag "JAVA_HOME:       $($env:JAVA_HOME)" "Gray"
$javaCmd = Get-Command java -ErrorAction SilentlyContinue
if ($javaCmd) {
    Write-Diag "Java Path:       $($javaCmd.Source)" "Gray"
    $javaVer = cmd.exe /c "java -version 2>&1"
    Write-Diag "Java Version Output:`n$($javaVer.Trim())" "Gray"
} else {
    Write-Diag "Java Executable: NOT FOUND" "Red"
}

# 3. Android SDK & Tools Inspection
Write-Diag "`n--- 3. Android SDK Inspection ---" "Yellow"
$localSdk = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Android\Sdk" } else { $null }
$sdkLocation = $null
if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) { $sdkLocation = $env:ANDROID_HOME }
elseif ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) { $sdkLocation = $env:ANDROID_SDK_ROOT }
elseif ($localSdk -and (Test-Path $localSdk)) { $sdkLocation = $localSdk }

if ($sdkLocation) {
    Write-Diag "SDK Location:    $sdkLocation" "Green"

    # Platforms
    $platformsDir = Join-Path $sdkLocation "platforms"
    if (Test-Path $platformsDir) {
        $platforms = (Get-ChildItem $platformsDir -Directory -ErrorAction SilentlyContinue).Name
        Write-Diag "Installed APIs:  $($platforms -join ', ')" "Gray"
    }

    # Build tools
    $buildToolsDir = Join-Path $sdkLocation "build-tools"
    if (Test-Path $buildToolsDir) {
        $buildTools = (Get-ChildItem $buildToolsDir -Directory -ErrorAction SilentlyContinue).Name
        Write-Diag "Build Tools:     $($buildTools -join ', ')" "Gray"
    }
} else {
    Write-Diag "SDK Location:    NOT FOUND" "Red"
}

# 4. Android Studio Inspection
Write-Diag "`n--- 4. Android Studio ---" "Yellow"
$localStudio = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Programs\Android Studio\bin\studio64.exe" } else { $null }
$studioPaths = @(
    "C:\Program Files\Android\Android Studio\bin\studio64.exe",
    "C:\Program Files\Android\Android Studio\bin\studio.exe",
    $localStudio
) | Where-Object { $_ -and (Test-Path $_) }

if ($studioPaths.Count -gt 0) {
    Write-Diag "Android Studio:  FOUND ($($studioPaths[0]))" "Green"
} else {
    Write-Diag "Android Studio:  NOT FOUND" "Yellow"
}

# 5. Connected Devices & AVDs
Write-Diag "`n--- 5. Device & Emulator Registry ---" "Yellow"
$adbPath = if ($sdkLocation) { Join-Path $sdkLocation "platform-tools\adb.exe" } else { "adb" }
$emuPath = if ($sdkLocation) { Join-Path $sdkLocation "emulator\emulator.exe" } else { "emulator" }

if (Test-Path $adbPath) {
    $adbDevices = cmd.exe /c "`"$adbPath`" devices -l 2>&1"
    $devLines = $adbDevices -split "`r?`n" | Where-Object { $_.Trim() -ne "" -and $_ -notmatch "^\* daemon" }
    Write-Diag "ADB Devices Output:`n$($devLines -join "`n")" "Gray"
} else {
    Write-Diag "ADB Path:        Not found at $adbPath" "Yellow"
}

if (Test-Path $emuPath) {
    $avds = cmd.exe /c "`"$emuPath`" -list-avds 2>&1"
    Write-Diag "AVDs Detected:   `n$($avds.Trim())" "Gray"
} else {
    Write-Diag "Emulator Path:   Not found at $emuPath" "Yellow"
}

Write-Diag "`n==========================================================" "Cyan"
Write-Diag " Diagnostics Collection Complete." "Cyan"
Write-Diag "==========================================================" "Cyan"

if ($OutputFile) {
    $diagOutput.ToString() | Out-File -FilePath $OutputFile -Encoding utf8
    Write-Host "Diagnostics saved to: $OutputFile" -ForegroundColor Green
}

exit 0
