# PeerLink Android Release Packaging Script
# Packages the Android APK into a relocatable distribution directory with SHA-256 signatures.

param(
    [string]$Version = "1.0.0-rc1",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$androidDir = Split-Path -Parent $scriptDir
$flutterDir = Join-Path $androidDir "app\flutter"
$apkPath = Join-Path $flutterDir "build\app\outputs\flutter-apk\app-release.apk"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Release Packaging: v$Version" -ForegroundColor Cyan
Write-Host " Base Directory: $androidDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify APK existence (or trigger build)
if (-not (Test-Path $apkPath)) {
    Write-Host "Release APK not found at $apkPath." -ForegroundColor Yellow
    Write-Host "Building Android Release APK via build-android.ps1..." -ForegroundColor Yellow
    & "$scriptDir\build-android.ps1" -Release
    if (-not (Test-Path $apkPath)) {
        Write-Error "Cannot package: Android release APK is missing."
        exit 1
    }
}

# 2. Prepare Distribution Layout
$targetDist = Join-Path $androidDir "$OutputDir\peerlink-android-$Version"
Write-Host "`n[1/2] Preparing distribution directory: $targetDist..." -ForegroundColor Cyan

if (Test-Path $targetDist) {
    Remove-Item -Recurse -Force $targetDist
}

New-Item -ItemType Directory -Path "$targetDist" -Force | Out-Null

$destApk = Join-Path $targetDist "peerlink-android-$Version.apk"
Copy-Item $apkPath $destApk -Force

# 3. Generate Release Manifest and SHA-256
Write-Host "`n[2/2] Generating release manifest and SHA-256 signatures..." -ForegroundColor Cyan
$apkHash = (Get-FileHash $destApk -Algorithm SHA256).Hash.ToLower()
$apkSize = (Get-Item $destApk).Length

$manifestContent = @"
{
  "product": "PeerLink",
  "version": "$Version",
  "platform": "android",
  "package_type": "apk",
  "application_id": "org.peerlink.peerlink",
  "min_sdk": 26,
  "target_sdk": 35,
  "protocol_version": "1.0.0",
  "apk_filename": "peerlink-android-$Version.apk",
  "apk_bytes": $apkSize,
  "apk_sha256": "$apkHash",
  "packaged_at": "$([DateTime]::UtcNow.ToString("o"))"
}
"@
Set-Content -Path "$targetDist\manifest.json" -Value $manifestContent -Encoding UTF8

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " Android Release Package created successfully!" -ForegroundColor Green
Write-Host " Output Directory: $targetDist" -ForegroundColor Green
Write-Host " APK File:         $destApk ($([Math]::Round($apkSize / 1MB, 2)) MB)" -ForegroundColor Green
Write-Host " SHA-256 Hash:     $apkHash" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
exit 0
