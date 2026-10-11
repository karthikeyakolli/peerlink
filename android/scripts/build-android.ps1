# PeerLink Android Application Build Script
# Builds the Android application package (APK or App Bundle).

param (
    [switch]$Bundle = $false,
    [switch]$Release = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$androidDir = Split-Path -Parent $scriptDir
$flutterDir = Join-Path $androidDir "app\flutter"
$androidHostDir = Join-Path $androidDir "app\flutter\android"
if (-not (Test-Path $androidHostDir)) {
    $androidHostDir = Join-Path $androidDir "app\android"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Application Build" -ForegroundColor Cyan
Write-Host " Base Directory: $androidDir" -ForegroundColor Cyan
Write-Host " Mode:           $(if ($Release) { 'Release' } else { 'Debug' })" -ForegroundColor Cyan
Write-Host " Target:         $(if ($Bundle) { 'AAB (App Bundle)' } else { 'APK' })" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Attempt Flutter Build
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    try {
        Push-Location $flutterDir
        $buildMode = if ($Release) { "--release" } else { "--debug" }
        $buildTarget = if ($Bundle) { "appbundle" } else { "apk" }
        Write-Host "Executing: flutter build $buildTarget $buildMode..." -ForegroundColor Gray
        & flutter build $buildTarget $buildMode
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Flutter build failed with exit code $LASTEXITCODE."
            exit $LASTEXITCODE
        }
        Write-Host "Android package built successfully via Flutter!" -ForegroundColor Green
        exit 0
    } finally {
        Pop-Location
    }
} else {
    Write-Host "NOTE: Flutter SDK is not installed on PATH." -ForegroundColor Yellow
    Write-Host "      Attempting native Gradle host compilation via gradlew..." -ForegroundColor Yellow

    # Check Gradle wrapper
    $gradlew = Join-Path $androidHostDir "gradlew.bat"
    if (Test-Path $gradlew) {
        try {
            Push-Location $androidHostDir
            $task = if ($Bundle) {
                if ($Release) { "bundleRelease" } else { "bundleDebug" }
            } else {
                if ($Release) { "assembleRelease" } else { "assembleDebug" }
            }
            Write-Host "Executing: .\gradlew.bat $task in $androidHostDir..." -ForegroundColor Gray
            & cmd.exe /c "gradlew.bat $task"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "BLOCKED: Native Gradle build failed with exit code $LASTEXITCODE." -ForegroundColor Red
                Write-Host "         (Note: Flutter Gradle plugin requires Flutter SDK to resolve dev.flutter dependencies)" -ForegroundColor Yellow
                exit 1
            }
            Write-Host "Native Android package built successfully via Gradle!" -ForegroundColor Green
            exit 0
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "BLOCKED: Both Flutter SDK and Gradle wrapper are missing or unavailable." -ForegroundColor Red
        exit 1
    }
}
