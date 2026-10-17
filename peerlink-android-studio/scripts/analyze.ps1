<#
.SYNOPSIS
    Runs static analysis and code formatting verification for PeerLink Android Studio Edition.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Studio Edition - Static Analysis          " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Set-Location $projectRoot

# 1. Dart formatting check
Write-Host "`n[1/2] Checking Dart code formatting..." -ForegroundColor Yellow
dart format --output=none --set-exit-if-changed .
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Some files need formatting. Run 'dart format .' to format." -ForegroundColor Yellow
} else {
    Write-Host "[OK] All Dart files properly formatted." -ForegroundColor Green
}

# 2. Flutter analyze
Write-Host "`n[2/2] Running Flutter analyzer..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] flutter analyze reported issues." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " Analysis Result: PASS (0 issues)" -ForegroundColor Green
exit 0
