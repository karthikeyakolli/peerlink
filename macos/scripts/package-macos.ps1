# PeerLink macOS Release Packaging Script (Cross-Platform)
# Packages the macOS Local Node and bundle structure into a relocatable distribution.

param(
    [string]$Version = "1.0.0-rc1",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$macosDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $macosDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink macOS Release Packaging: v$Version" -ForegroundColor Cyan
Write-Host " Base Directory: $macosDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate Node JAR
$nodeJar = $null
$localJar = Join-Path $macosDir "target\peerlink-macos-node-0.1.0-SNAPSHOT.jar"
$shadedJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"

if (Test-Path $localJar) {
    $nodeJar = $localJar
} elseif (Test-Path $shadedJar) {
    $nodeJar = $shadedJar
}

if (-not $nodeJar) {
    Write-Host "Local Node JAR not found at $localJar or $shadedJar." -ForegroundColor Yellow
    Write-Host "Attempting build via build-macos.ps1..." -ForegroundColor Yellow
    & "$scriptDir\build-macos.ps1" -SkipUi
    if (Test-Path $localJar) {
        $nodeJar = $localJar
    } elseif (Test-Path $shadedJar) {
        $nodeJar = $shadedJar
    } else {
        Write-Error "Cannot package: Local Node JAR is missing."
        exit 1
    }
}

# 2. Prepare PeerLink.app Bundle Layout
$targetDist = Join-Path $macosDir "$OutputDir\peerlink-macos-$Version"
$appBundle = Join-Path $targetDist "PeerLink.app"
$contents = Join-Path $appBundle "Contents"

Write-Host "`n[1/3] Preparing macOS Application Bundle: $appBundle..." -ForegroundColor Cyan

if (Test-Path $targetDist) {
    Remove-Item -Recurse -Force $targetDist
}

New-Item -ItemType Directory -Path "$contents\MacOS" -Force | Out-Null
New-Item -ItemType Directory -Path "$contents\Java" -Force | Out-Null
New-Item -ItemType Directory -Path "$contents\Resources\config" -Force | Out-Null

Copy-Item $nodeJar "$contents\Java\peerlink-macos-node.jar" -Force

# Launcher Script (macOS bash format)
$launcherContent = @"
#!/usr/bin/env bash
set -euo pipefail
CONTENTS_DIR="`$(cd "`$(dirname "`"${BASH_SOURCE[0]}`"")/.." && pwd)"

if [ -n "`${JAVA_HOME:-}" ] && [ -x "`$JAVA_HOME/bin/java" ]; then
    JAVA_CMD="`$JAVA_HOME/bin/java"
elif command -v java >/dev/null 2>&1; then
    JAVA_CMD="java"
else
    echo "ERROR: Java 21+ runtime is required to run PeerLink Local Node." >&2
    exit 1
fi

exec "`$JAVA_CMD" -Dfile.encoding=UTF-8 -jar "`$CONTENTS_DIR/Java/peerlink-macos-node.jar" "`$@"
"@
[System.IO.File]::WriteAllText("$contents\MacOS\peerlink-node", $launcherContent.Replace("`r`n", "`n"), [System.Text.Encoding]::UTF8)

# Info.plist
$infoPlist = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>peerlink_app</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.peerlink.desktop</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>PeerLink</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$Version</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026 PeerLink. All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
"@
[System.IO.File]::WriteAllText("$contents\Info.plist", $infoPlist.Replace("`r`n", "`n"), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$contents\PkgInfo", "APPL????`n", [System.Text.Encoding]::UTF8)

# Production Config
$configContent = @"
# PeerLink macOS Release Configuration (v$Version)
peerlink.node.port=50051
peerlink.node.bind-host=127.0.0.1
peerlink.storage.max-db-mb=256
peerlink.storage.staging-retention-hours=24
peerlink.transfer.max-concurrent=4
peerlink.security.fail-closed-scanning=true
"@
[System.IO.File]::WriteAllText("$contents\Resources\config\application.properties", $configContent.Replace("`r`n", "`n"), [System.Text.Encoding]::UTF8)

# Check for compiled Flutter macOS desktop release bundle
$flutterReleaseApp = Join-Path $macosDir "app\flutter\build\macos\Build\Products\Release\peerlink.app"
if (Test-Path $flutterReleaseApp) {
    Write-Host "`n[2/3] Merging compiled Flutter macOS release application bundle..." -ForegroundColor Cyan
    Copy-Item -Recurse -Force "$flutterReleaseApp\Contents\MacOS\*" "$contents\MacOS\"
} else {
    Write-Host "`n[2/3] Flutter macOS release .app bundle not present in Release build (skipped native binary merge)." -ForegroundColor Gray
}

# 3. Generate Release Manifest and Checksums
Write-Host "`n[3/3] Generating release manifest and SHA-256 signatures..." -ForegroundColor Cyan
$jarHash = (Get-FileHash "$contents\Java\peerlink-macos-node.jar" -Algorithm SHA256).Hash.ToLower()

$manifestContent = @"
{
  "name": "PeerLink macOS",
  "version": "$Version",
  "buildPlatform": "macos",
  "architecture": "universal2",
  "timestampUtc": "$([DateTime]::UtcNow.ToString('o'))",
  "components": {
    "localNode": {
      "jar": "PeerLink.app/Contents/Java/peerlink-macos-node.jar",
      "sha256": "$jarHash",
      "minJavaVersion": 21
    },
    "bundle": "PeerLink.app",
    "launcher": "PeerLink.app/Contents/MacOS/peerlink-node"
  }
}
"@
[System.IO.File]::WriteAllText("$targetDist\manifest.json", $manifestContent.Replace("`r`n", "`n"), [System.Text.Encoding]::UTF8)

# Create ZIP archive (and tar.gz if tar is available)
$distParent = Join-Path $macosDir $OutputDir
$zipFile = Join-Path $distParent "peerlink-macos-$Version.zip"
if (Test-Path $zipFile) { Remove-Item -Force $zipFile }
Compress-Archive -Path "$targetDist\*" -DestinationPath $zipFile -CompressionLevel Optimal
$zipHash = (Get-FileHash $zipFile -Algorithm SHA256).Hash.ToLower()
[System.IO.File]::WriteAllText("$zipFile.sha256", "$zipHash  peerlink-macos-$Version.zip`n", [System.Text.Encoding]::UTF8)

$tarCmd = Get-Command tar.exe -ErrorAction SilentlyContinue
if ($tarCmd) {
    $tarFile = Join-Path $distParent "peerlink-macos-$Version.tar.gz"
    try {
        Push-Location $distParent
        & tar.exe -czf "peerlink-macos-$Version.tar.gz" "peerlink-macos-$Version"
        if (Test-Path $tarFile) {
            $tarHash = (Get-FileHash $tarFile -Algorithm SHA256).Hash.ToLower()
            [System.IO.File]::WriteAllText("$tarFile.sha256", "$tarHash  peerlink-macos-$Version.tar.gz`n", [System.Text.Encoding]::UTF8)
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
