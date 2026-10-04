# PeerLink Release Packaging Script (PowerShell)
param(
    [string]$TargetPlatform = "windows",
    [string]$Version = "1.0.0-rc1",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "================================================" -ForegroundColor Cyan
Write-Host " PeerLink Release Packaging: $TargetPlatform v$Version" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# 1. Ensure Maven build of shaded fat JAR if missing
$JarSource = "$RootDir\desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"
if (-not (Test-Path $JarSource)) {
    Write-Host "`n[1/4] Building standalone shaded Desktop Node..." -ForegroundColor Yellow
    if (Test-Path "D:\tools\apache-maven-3.9.9\bin") {
        $env:PATH = "D:\tools\apache-maven-3.9.9\bin;" + $env:PATH
    }
    mvn package -DskipTests=true -pl desktop-node -am
    if (-not (Test-Path $JarSource)) {
        throw "Target JAR not found: $JarSource"
    }
}

# 2. Prepare Distribution Structure
Write-Host "`n[2/4] Preparing distribution layout in $OutputDir/$TargetPlatform..." -ForegroundColor Yellow
$TargetDist = "$RootDir\$OutputDir\$TargetPlatform\peerlink-$Version"
if (Test-Path $TargetDist) {
    Remove-Item -Recurse -Force $TargetDist
}

if ($TargetPlatform -eq "windows") {
    New-Item -ItemType Directory -Path "$TargetDist\bin" -Force | Out-Null
    New-Item -ItemType Directory -Path "$TargetDist\lib" -Force | Out-Null
    New-Item -ItemType Directory -Path "$TargetDist\runtime" -Force | Out-Null
    New-Item -ItemType Directory -Path "$TargetDist\config" -Force | Out-Null

    Copy-Item $JarSource "$TargetDist\lib\peerlink-desktop-node.jar" -Force

    $LauncherContent = @"
@echo off
setlocal
set PEERLINK_HOME=%~dp0..
if exist "%PEERLINK_HOME%\runtime\bin\java.exe" (
    set JAVA_EXE="%PEERLINK_HOME%\runtime\bin\java.exe"
) else (
    set JAVA_EXE=java
)

%JAVA_EXE% -Dfile.encoding=UTF-8 -jar "%PEERLINK_HOME%\lib\peerlink-desktop-node.jar" %*
"@
    Set-Content -Path "$TargetDist\bin\peerlink-node.bat" -Value $LauncherContent -Encoding Ascii

    # Production config
    $ConfigContent = @"
# PeerLink Desktop Release Configuration (v$Version)
peerlink.node.port=50051
peerlink.node.bind-host=127.0.0.1
peerlink.storage.max-db-mb=256
peerlink.storage.staging-retention-hours=24
peerlink.transfer.max-concurrent=4
peerlink.security.fail-closed-scanning=true
"@
    Set-Content -Path "$TargetDist\config\application.properties" -Value $ConfigContent -Encoding UTF8

} elseif ($TargetPlatform -eq "linux") {
    New-Item -ItemType Directory -Path "$TargetDist\bin" -Force | Out-Null
    New-Item -ItemType Directory -Path "$TargetDist\lib" -Force | Out-Null
    New-Item -ItemType Directory -Path "$TargetDist\config" -Force | Out-Null
    New-Item -ItemType Directory -Path "$TargetDist\share\applications" -Force | Out-Null

    Copy-Item $JarSource "$TargetDist\lib\peerlink-desktop-node.jar" -Force

    $LauncherContent = @'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -x "$DIR/runtime/bin/java" ]; then
    JAVA_EXE="$DIR/runtime/bin/java"
else
    JAVA_EXE="java"
fi
exec "$JAVA_EXE" -Dfile.encoding=UTF-8 -jar "$DIR/lib/peerlink-desktop-node.jar" "$@"
'@
    Set-Content -Path "$TargetDist\bin\peerlink-node" -Value $LauncherContent -Encoding Ascii

    $DesktopEntry = @"
[Desktop Entry]
Name=PeerLink
Comment=Privacy-First Distributed Personal Data Node
Exec=peerlink-node
Icon=peerlink
Terminal=false
Type=Application
Categories=Network;FileTransfer;
"@
    Set-Content -Path "$TargetDist\share\applications\peerlink.desktop" -Value $DesktopEntry -Encoding UTF8

} elseif ($TargetPlatform -eq "macos") {
    $AppDir = "$TargetDist\PeerLink.app\Contents"
    New-Item -ItemType Directory -Path "$AppDir\MacOS" -Force | Out-Null
    New-Item -ItemType Directory -Path "$AppDir\Resources" -Force | Out-Null
    New-Item -ItemType Directory -Path "$AppDir\Java" -Force | Out-Null

    Copy-Item $JarSource "$AppDir\Java\peerlink-desktop-node.jar" -Force

    $LauncherContent = @'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec java -Dfile.encoding=UTF-8 -jar "$DIR/Java/peerlink-desktop-node.jar" "$@"
'@
    Set-Content -Path "$AppDir\MacOS\PeerLink" -Value $LauncherContent -Encoding Ascii

    $Entitlements = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
"@
    Set-Content -Path "$TargetDist\entitlements.plist" -Value $Entitlements -Encoding UTF8

} elseif ($TargetPlatform -eq "android") {
    New-Item -ItemType Directory -Path "$TargetDist\apk" -Force | Out-Null
    New-Item -ItemType Directory -Path "$TargetDist\bundle" -Force | Out-Null

    # Create release metadata and manifest
    $AndroidMeta = @"
PackageName: org.peerlink.app
MinSdk: 26 (Android 8.0 Oreo)
TargetSdk: 34 (Android 14)
VersionName: $Version
VersionCode: 100
Permissions: INTERNET, ACCESS_NETWORK_STATE, FOREGROUND_SERVICE_DATA_SYNC, WAKE_LOCK
"@
    Set-Content -Path "$TargetDist\apk\release-info.txt" -Value $AndroidMeta -Encoding UTF8
}

# 3. Generate Release Manifest and Checksum
Write-Host "`n[3/4] Generating release manifest and SHA-256 signatures..." -ForegroundColor Yellow
$JarHash = (Get-FileHash $JarSource -Algorithm SHA256).Hash.ToLower()

$ManifestContent = @"
{
  "product": "PeerLink",
  "version": "$Version",
  "platform": "$TargetPlatform",
  "protocol_version": "1.0.0",
  "schema_version": 3,
  "min_supported_protocol": "1.0.0",
  "node_jar_sha256": "$JarHash",
  "packaged_at": "$([DateTime]::UtcNow.ToString("o"))"
}
"@
Set-Content -Path "$TargetDist\manifest.json" -Value $ManifestContent -Encoding UTF8

Write-Host "`nPackage built successfully at: $TargetDist" -ForegroundColor Green
Write-Host "SHA256: $JarHash" -ForegroundColor Green
