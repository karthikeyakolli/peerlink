# PeerLink Android Flutter Test Runner
# Runs the Dart and Flutter widget, unit, and IPC integration test suite.

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$androidDir = Split-Path -Parent $scriptDir
$flutterDir = Join-Path $androidDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Flutter Test Suite" -ForegroundColor Cyan
Write-Host " Test Directory: $flutterDir\test" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Host "`nBLOCKED: Flutter SDK is not installed on PATH." -ForegroundColor Red
    Write-Host "         Flutter unit and integration tests cannot be executed." -ForegroundColor Yellow
    Write-Host "         Install Flutter from: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    exit 1
}

try {
    Push-Location $flutterDir
    Write-Host "Executing: flutter test in $flutterDir..." -ForegroundColor Gray
    & flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter test suite failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
    Write-Host "`nAll Flutter Android tests passed successfully!" -ForegroundColor Green
    exit 0
} finally {
    Pop-Location
}
