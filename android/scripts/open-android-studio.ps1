# PeerLink Open Android Studio Launcher
# Opens the native Android host project in Android Studio.

param (
    [switch]$DryRun = $false
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$androidDir = Split-Path -Parent $scriptDir
$androidHostDir = Join-Path $androidDir 'app\flutter\android'
if (-not (Test-Path $androidHostDir)) {
    $androidHostDir = Join-Path $androidDir 'app\android'
}

Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host ' PeerLink Android Host — Android Studio Launcher' -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host "Target Host Project: $androidHostDir" -ForegroundColor Gray

# Locate Android Studio executable
$localStudio = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Programs\Android Studio\bin\studio64.exe" } else { $null }
$candidateStudio = @(
    "C:\Program Files\Android\Android Studio\bin\studio64.exe",
    "C:\Program Files\Android\Android Studio\bin\studio.exe",
    $localStudio
) | Where-Object { $_ -and (Test-Path $_) }

$studioExe = $null
if ($candidateStudio.Count -gt 0) {
    $studioExe = $candidateStudio[0]
} else {
    $cmd = Get-Command studio64 -ErrorAction SilentlyContinue
    if ($cmd) { $studioExe = $cmd.Source }
}

if (-not $studioExe) {
    Write-Host 'BLOCKED: Android Studio is not installed on this machine.' -ForegroundColor Red
    Write-Host 'Download and install Android Studio from:' -ForegroundColor Yellow
    Write-Host '  https://developer.android.com/studio' -ForegroundColor Yellow
    exit 1
}

Write-Host "Launcher: $studioExe" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "[DRY RUN] Would execute: Start-Process -FilePath '$studioExe' -ArgumentList ('`"' + '$androidHostDir' + '`"')" -ForegroundColor Yellow
    exit 0
}

Write-Host "Launching Android Studio..." -ForegroundColor Green
Start-Process -FilePath $studioExe -ArgumentList ('"' + $androidHostDir + '"')
Write-Host "Android Studio launched successfully." -ForegroundColor Green
exit 0
