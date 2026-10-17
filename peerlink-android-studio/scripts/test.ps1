<#
.SYNOPSIS
    Runs Flutter tests and native Android unit tests.
#>
[CmdletBinding()]
param(
    [switch]$DeviceDependent
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Studio Edition - Test Suite Runner        " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Set-Location $projectRoot

# 1. Flutter unit and widget tests
Write-Host "`n[1/2] Running Flutter unit & widget tests..." -ForegroundColor Yellow
flutter test --reporter expanded
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] flutter test failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "[OK] All Flutter tests passed!" -ForegroundColor Green

# 2. Native Android Unit Tests
Write-Host "`n[2/2] Running native Android unit tests via Gradle..." -ForegroundColor Yellow
$androidDir = Join-Path $projectRoot "android"
Set-Location $androidDir
.\gradlew.bat testDebugUnitTest --no-daemon
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Gradle testDebugUnitTest failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "[OK] All native Android unit tests passed!" -ForegroundColor Green

Set-Location $projectRoot
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " Test Suite Result: ALL TESTS PASSED (PASS)" -ForegroundColor Green
exit 0
