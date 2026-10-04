# PeerLink Desktop Release Packaging Script (PowerShell)
param(
    [string]$TargetPlatform = "windows",
    [string]$Version = "1.0.0",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "================================================" -ForegroundColor Cyan
Write-Host " PeerLink Desktop Release Packaging: $TargetPlatform v$Version" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# 1. Ensure Maven build of shaded fat JAR
Write-Host "`n[1/4] Building standalone shaded Desktop Node..." -ForegroundColor Yellow
$env:PATH = "C:\Users\WIN_10\apache-maven\apache-maven-3.9.6\bin;" + $env:PATH
mvn package -DskipTests -pl desktop-node -am

$JarSource = "$RootDir\desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"
if (-not (Test-Path $JarSource)) {
    throw "Target JAR not found: $JarSource"
}

# 2. Prepare Distribution Structure
Write-Host "`n[2/4] Preparing distribution layout in $OutputDir/$TargetPlatform..." -ForegroundColor Yellow
$TargetDist = "$RootDir\$OutputDir\$TargetPlatform\peerlink-$Version"
if (Test-Path $TargetDist) {
    Remove-Item -Recurse -Force $TargetDist
}
New-Item -ItemType Directory -Path "$TargetDist\bin" -Force | Out-Null
New-Item -ItemType Directory -Path "$TargetDist\lib" -Force | Out-Null
New-Item -ItemType Directory -Path "$TargetDist\runtime" -Force | Out-Null
New-Item -ItemType Directory -Path "$TargetDist\config" -Force | Out-Null

# Copy fat JAR
Copy-Item $JarSource "$TargetDist\lib\peerlink-desktop-node.jar" -Force

# 3. Create Desktop Launcher and Bundled JRE Configuration
Write-Host "`n[3/4] Creating platform launcher..." -ForegroundColor Yellow
if ($TargetPlatform -eq "windows") {
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
} else {
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
}

# 4. Generate Release Manifest and Checksum
Write-Host "`n[4/4] Generating release manifest and SHA-256 signatures..." -ForegroundColor Yellow
$JarHash = (Get-FileHash "$TargetDist\lib\peerlink-desktop-node.jar" -Algorithm SHA256).Hash.ToLower()

$ManifestContent = @"
{
  "product": "PeerLink Desktop",
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
