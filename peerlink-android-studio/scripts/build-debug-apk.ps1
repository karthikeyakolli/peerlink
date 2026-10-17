<#
.SYNOPSIS
    Builds the standalone Android Debug APK and reports the artifact location and size.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Studio Edition - Build Debug APK          " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Set-Location $projectRoot

Write-Host "`n[1/2] Compiling debug APK via Flutter build..." -ForegroundColor Yellow
$sw = [System.Diagnostics.Stopwatch]::StartNew()
flutter build apk --debug
$buildExit = $LASTEXITCODE
$sw.Stop()

if ($buildExit -ne 0) {
    Write-Host "[FAIL] APK compilation failed with exit code $buildExit" -ForegroundColor Red
    exit $buildExit
}

# 2. Inspect resulting APK
Write-Host "`n[2/2] Inspecting generated APK..." -ForegroundColor Yellow
$apkCandidates = @(
    (Join-Path $projectRoot "build\app\outputs\flutter-apk\app-debug.apk"),
    (Join-Path $projectRoot "android\app\build\outputs\apk\debug\app-debug.apk")
)

$apkFound = $null
foreach ($c in $apkCandidates) {
    if (Test-Path $c) {
        $apkFound = Get-Item $c
        break
    }
}

if ($apkFound) {
    $sizeMb = [math]::Round($apkFound.Length / 1MB, 2)
    Write-Host "  Artifact Path: $($apkFound.FullName)" -ForegroundColor Green
    Write-Host "  Artifact Size: $sizeMb MB ($($apkFound.Length) bytes)" -ForegroundColor Green
    Write-Host "  Build Duration: $($sw.Elapsed.TotalSeconds.ToString("F1"))s" -ForegroundColor Green
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " APK BUILD SUCCESSFUL (PASS)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] Output APK was not found at expected paths!" -ForegroundColor Red
    exit 1
}
