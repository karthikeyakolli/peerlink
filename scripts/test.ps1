# PeerLink Monorepo Test Script (PowerShell)
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "=== Running PeerLink Monorepo Test Suite ===" -ForegroundColor Cyan

# 1. Dependency boundary test
Write-Host "1. Testing dependency boundaries..." -ForegroundColor Yellow
& "$PSScriptRoot/check-deps.ps1"

# 2. Java unit & integration tests
Write-Host "2. Running Java Core & Desktop Node tests (JUnit 5)..." -ForegroundColor Yellow
mvn clean test -B

# 3. Flutter tests
Write-Host "3. Running Flutter tests..." -ForegroundColor Yellow
if (Test-Path "apps/peerlink-app") {
    Push-Location "apps/peerlink-app"
    flutter test
    Pop-Location
}

Write-Host "=== All PeerLink Tests Succeeded ===" -ForegroundColor Green
