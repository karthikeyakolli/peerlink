# PeerLink Master Cross-Platform Release Packaging Automation
# Packages both Windows Native Desktop and Android Mobile into signed release bundles.

param(
    [string]$Version = "1.0.0-rc1",
    [switch]$SkipWindows = $false,
    [switch]$SkipAndroid = $false
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Master Cross-Platform Release Packaging" -ForegroundColor Cyan
Write-Host " Target Release Version: v$Version" -ForegroundColor Cyan
Write-Host " Platforms: $(if (-not $SkipWindows) { 'Windows ' })$(if (-not $SkipAndroid) { 'Android' })" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$results = @{}

# 1. Package Windows
if (-not $SkipWindows) {
    Write-Host "`n>>> [1/2] Packaging Windows Desktop Release Package..." -ForegroundColor Yellow
    & "$repoRoot\windows\scripts\package-windows.ps1" -Version $Version
    if ($LASTEXITCODE -eq 0) {
        $winDist = "$repoRoot\windows\dist\peerlink-windows-$Version"
        $winZip = "$repoRoot\windows\dist\peerlink-windows-$Version.zip"
        $winManifest = Get-Content "$winDist\manifest.json" | ConvertFrom-Json
        $results["Windows"] = [PSCustomObject]@{
            Platform = "Windows (x64)"
            ArtifactDir = $winDist
            ZipArchive = $winZip
            Executable = "$winDist\bin\peerlink.exe"
            NodeJar = "$winDist\lib\peerlink-windows-node.jar"
            NodeSHA256 = $winManifest.node_jar_sha256
            Status = "SUCCESS"
        }
    } else {
        Write-Error "Windows packaging failed."
    }
}

# 2. Package Android
if (-not $SkipAndroid) {
    Write-Host "`n>>> [2/2] Packaging Android Mobile Release Package..." -ForegroundColor Yellow
    & "$repoRoot\android\scripts\package-android.ps1" -Version $Version
    if ($LASTEXITCODE -eq 0) {
        $androidDist = "$repoRoot\android\dist\peerlink-android-$Version"
        $androidManifest = Get-Content "$androidDist\manifest.json" | ConvertFrom-Json
        $results["Android"] = [PSCustomObject]@{
            Platform = "Android (APK)"
            ArtifactDir = $androidDist
            ApkFile = "$androidDist\peerlink-android-$Version.apk"
            ApkBytes = $androidManifest.apk_bytes
            ApkSHA256 = $androidManifest.apk_sha256
            Status = "SUCCESS"
        }
    } else {
        Write-Error "Android packaging failed."
    }
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " PeerLink Standalone Release Packaging Summary" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
foreach ($k in $results.Keys) {
    $res = $results[$k]
    Write-Host "`nPlatform: $($res.Platform)" -ForegroundColor Cyan
    Write-Host "  Directory:   $($res.ArtifactDir)"
    if ($res.ZipArchive -and (Test-Path $res.ZipArchive)) {
        Write-Host "  ZIP Archive: $($res.ZipArchive)"
    }
    if ($res.NodeSHA256) {
        Write-Host "  Node SHA256: $($res.NodeSHA256)"
    }
    if ($res.ApkSHA256) {
        Write-Host "  APK File:    $($res.ApkFile) ($([Math]::Round($res.ApkBytes / 1MB, 2)) MB)"
        Write-Host "  APK SHA256:  $($res.ApkSHA256)"
    }
}
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " All standalone release packages assembled successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
