# PeerLink Linux Release Packaging Script (Cross-Platform / Windows Host)
# Packages the Linux Local Node and configuration into a relocatable distribution.

param(
    [string]$Version = "1.0.0-rc1",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$linuxDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $linuxDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Linux Release Packaging: v$Version" -ForegroundColor Cyan
Write-Host " Base Directory: $linuxDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate Node JAR
$nodeJar = $null
$localJar = Join-Path $linuxDir "target\peerlink-linux-node-0.1.0-SNAPSHOT.jar"
$shadedJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"

if (Test-Path $localJar) {
    $nodeJar = $localJar
} elseif (Test-Path $shadedJar) {
    $nodeJar = $shadedJar
}

if (-not $nodeJar) {
    Write-Host "Local Node JAR not found at $localJar or $shadedJar." -ForegroundColor Yellow
    Write-Host "Attempting build via build-linux.ps1..." -ForegroundColor Yellow
    & "$scriptDir\build-linux.ps1" -SkipUi
    if (Test-Path $localJar) {
        $nodeJar = $localJar
    } elseif (Test-Path $shadedJar) {
        $nodeJar = $shadedJar
    } else {
        Write-Error "Cannot package: Local Node JAR is missing."
        exit 1
    }
}

# 2. Prepare Distribution Layout
$targetDist = Join-Path $linuxDir "$OutputDir\peerlink-linux-$Version"
Write-Host "`n[1/3] Preparing distribution directory: $targetDist..." -ForegroundColor Cyan

if (Test-Path $targetDist) {
    Remove-Item -Recurse -Force $targetDist
}

New-Item -ItemType Directory -Path "$targetDist\bin" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDist\lib" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDist\share\applications" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDist\share\icons\hicolor\512x512\apps" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDist\config" -Force | Out-Null

Copy-Item $nodeJar "$targetDist\lib\peerlink-linux-node.jar" -Force

# Launcher Script (Linux bash format)
$launcherContent = @"
#!/usr/bin/env bash
set -euo pipefail
BIN_DIR="`$(cd "`$(dirname "`"${BASH_SOURCE[0]}`"")" && pwd)"
PEERLINK_HOME="`$(cd "`$BIN_DIR/.." && pwd)"

if [ -n "`${JAVA_HOME:-}" ] && [ -x "`$JAVA_HOME/bin/java" ]; then
    JAVA_CMD="`$JAVA_HOME/bin/java"
elif command -v java >/dev/null 2>&1; then
    JAVA_CMD="java"
else
    echo "ERROR: Java 21+ runtime is required to run PeerLink Local Node." >&2
    exit 1
fi

exec "`$JAVA_CMD" -Dfile.encoding=UTF-8 -jar "`$PEERLINK_HOME/lib/peerlink-linux-node.jar" "`$@"
"@
[System.IO.File]::WriteAllText("$targetDist\bin\peerlink-node", $launcherContent.Replace("`r`n", "`n"), [System.Text.Encoding]::UTF8)

# Production Config
$configContent = @"
# PeerLink Linux Release Configuration (v$Version)
peerlink.node.port=50051
peerlink.node.bind-host=127.0.0.1
peerlink.storage.max-db-mb=256
peerlink.storage.staging-retention-hours=24
peerlink.transfer.max-concurrent=4
peerlink.security.fail-closed-scanning=true
"@
[System.IO.File]::WriteAllText("$targetDist\config\application.properties", $configContent.Replace("`r`n", "`n"), [System.Text.Encoding]::UTF8)

# Desktop Entry
$desktopEntry = @"
[Desktop Entry]
Version=1.0
Type=Application
Name=PeerLink
GenericName=Local-First P2P File Transfer & Collaboration
Comment=Secure, end-to-end encrypted direct peer-to-peer file synchronization and transfer
Exec=peerlink-app
Icon=peerlink
Terminal=false
Categories=Network;FileTransfer;P2P;Utility;
Keywords=p2p;transfer;sync;share;encrypted;peerlink;
StartupWMClass=peerlink_app
MimeType=application/x-peerlink-package;
"@
[System.IO.File]::WriteAllText("$targetDist\share\applications\peerlink.desktop", $desktopEntry.Replace("`r`n", "`n"), [System.Text.Encoding]::UTF8)

# Copy Icon if present
$iconSrc = Join-Path $linuxDir "app\flutter\assets\icons\app_icon.png"
if (Test-Path $iconSrc) {
    Copy-Item $iconSrc "$targetDist\share\icons\hicolor\512x512\apps\peerlink.png" -Force
}

# Check for compiled Flutter Linux desktop bundle
$flutterBundle = Join-Path $linuxDir "app\flutter\build\linux\x64\release\bundle"
if (Test-Path $flutterBundle) {
    Write-Host "`n[2/3] Including compiled Flutter Linux desktop bundle..." -ForegroundColor Cyan
    Copy-Item -Recurse -Force "$flutterBundle\*" "$targetDist\bin\"
} else {
    Write-Host "`n[2/3] Flutter Linux desktop bundle not present in Release build (skipped)." -ForegroundColor Gray
}

# 3. Generate Release Manifest and Checksums
Write-Host "`n[3/3] Generating release manifest and SHA-256 signatures..." -ForegroundColor Cyan
$jarHash = (Get-FileHash "$targetDist\lib\peerlink-linux-node.jar" -Algorithm SHA256).Hash.ToLower()

$manifestContent = @"
{
  "name": "PeerLink Linux",
  "version": "$Version",
  "buildPlatform": "linux",
  "architecture": "x86_64",
  "timestampUtc": "$([DateTime]::UtcNow.ToString('o'))",
  "components": {
    "localNode": {
      "jar": "lib/peerlink-linux-node.jar",
      "sha256": "$jarHash",
      "minJavaVersion": 21
    },
    "desktopEntry": "share/applications/peerlink.desktop",
    "launcher": "bin/peerlink-node"
  }
}
"@
[System.IO.File]::WriteAllText("$targetDist\manifest.json", $manifestContent.Replace("`r`n", "`n"), [System.Text.Encoding]::UTF8)

# Create ZIP archive (and tar.gz if tar is available)
$distParent = Join-Path $linuxDir $OutputDir
$zipFile = Join-Path $distParent "peerlink-linux-$Version.zip"
if (Test-Path $zipFile) { Remove-Item -Force $zipFile }
Compress-Archive -Path "$targetDist\*" -DestinationPath $zipFile -CompressionLevel Optimal
$zipHash = (Get-FileHash $zipFile -Algorithm SHA256).Hash.ToLower()
[System.IO.File]::WriteAllText("$zipFile.sha256", "$zipHash  peerlink-linux-$Version.zip`n", [System.Text.Encoding]::UTF8)

# If tar is available, also produce tar.gz
$tarCmd = Get-Command tar.exe -ErrorAction SilentlyContinue
if ($tarCmd) {
    $tarFile = Join-Path $distParent "peerlink-linux-$Version.tar.gz"
    try {
        Push-Location $distParent
        & tar.exe -czf "peerlink-linux-$Version.tar.gz" "peerlink-linux-$Version"
        if (Test-Path $tarFile) {
            $tarHash = (Get-FileHash $tarFile -Algorithm SHA256).Hash.ToLower()
            [System.IO.File]::WriteAllText("$tarFile.sha256", "$tarHash  peerlink-linux-$Version.tar.gz`n", [System.Text.Encoding]::UTF8)
            Write-Host "Created tarball: $tarFile (SHA-256: $tarHash)" -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Packaging Successful!" -ForegroundColor Green
Write-Host " Directory: $targetDist" -ForegroundColor Gray
Write-Host " Archive:   $zipFile (SHA-256: $zipHash)" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

exit 0
