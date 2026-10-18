# PeerLink Windows Release Packaging Script
# Packages the Windows Local Node and native desktop application into a relocatable distribution.

param(
    [string]$Version = "1.0.0-rc1",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$windowsDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $windowsDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Windows Release Packaging: v$Version" -ForegroundColor Cyan
Write-Host " Base Directory: $windowsDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate Node JAR
$nodeJar = $null
$localJar = Join-Path $windowsDir "target\peerlink-windows-node-0.1.0-SNAPSHOT.jar"

if (Test-Path $localJar) {
    $nodeJar = $localJar
}

if (-not $nodeJar) {
    Write-Host "Local Node JAR not found at $localJar." -ForegroundColor Yellow
    Write-Host "Building Windows Local Node jar..." -ForegroundColor Yellow
    & "$repoRoot\mvnw.cmd" package -DskipTests -f "$windowsDir\pom.xml" -B
    if (Test-Path $localJar) {
        $nodeJar = $localJar
    } else {
        Write-Error "Cannot package: Local Node JAR is missing."
        exit 1
    }
}

# 2. Prepare Distribution Layout
$targetDist = Join-Path $windowsDir "$OutputDir\peerlink-windows-$Version"
Write-Host "`n[1/3] Preparing distribution directory: $targetDist..." -ForegroundColor Cyan

if (Test-Path $targetDist) {
    Remove-Item -Recurse -Force $targetDist
}

New-Item -ItemType Directory -Path "$targetDist\bin" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDist\lib" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDist\runtime" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDist\config" -Force | Out-Null

Copy-Item $nodeJar "$targetDist\lib\peerlink-windows-node.jar" -Force

# Launcher Script
$launcherContent = @"
@echo off
setlocal
set PEERLINK_HOME=%~dp0..
if exist "%PEERLINK_HOME%\runtime\bin\java.exe" (
    set JAVA_EXE="%PEERLINK_HOME%\runtime\bin\java.exe"
) else (
    set JAVA_EXE=java
)

%JAVA_EXE% -Dfile.encoding=UTF-8 -jar "%PEERLINK_HOME%\lib\peerlink-windows-node.jar" %*
"@
Set-Content -Path "$targetDist\bin\peerlink-node.bat" -Value $launcherContent -Encoding Ascii

# Production Config
$configContent = @"
# PeerLink Windows Release Configuration (v$Version)
peerlink.node.port=50051
peerlink.node.bind-host=127.0.0.1
peerlink.storage.max-db-mb=256
peerlink.storage.staging-retention-hours=24
peerlink.transfer.max-concurrent=4
peerlink.security.fail-closed-scanning=true
"@
Set-Content -Path "$targetDist\config\application.properties" -Value $configContent -Encoding UTF8

# Check if Flutter Windows native bundle exists
$flutterReleaseDir = Join-Path $windowsDir "app\flutter\build\windows\runner\Release"
if (Test-Path $flutterReleaseDir) {
    Write-Host "`n[2/3] Including compiled Flutter Windows desktop runner..." -ForegroundColor Cyan
    Copy-Item -Recurse -Force "$flutterReleaseDir\*" "$targetDist\bin\"
} else {
    Write-Host "`n[2/3] Flutter Windows desktop runner not present in Release build (skipped)." -ForegroundColor Gray
}

# 3. Generate Release Manifest and SHA-256
Write-Host "`n[3/3] Generating release manifest and SHA-256 signatures..." -ForegroundColor Cyan
$jarHash = (Get-FileHash "$targetDist\lib\peerlink-windows-node.jar" -Algorithm SHA256).Hash.ToLower()

$manifestContent = @"
{
  "product": "PeerLink",
  "version": "$Version",
  "platform": "windows",
  "protocol_version": "1.0.0",
  "schema_version": 3,
  "min_supported_protocol": "1.0.0",
  "node_jar_sha256": "$jarHash",
  "packaged_at": "$([DateTime]::UtcNow.ToString("o"))"
}
"@
Set-Content -Path "$targetDist\manifest.json" -Value $manifestContent -Encoding UTF8

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " Windows Release Package created successfully!" -ForegroundColor Green
Write-Host " Output Directory: $targetDist" -ForegroundColor Green
Write-Host " Local Node SHA256: $jarHash" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
exit 0
