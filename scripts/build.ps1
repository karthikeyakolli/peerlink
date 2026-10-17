# PeerLink Monorepo Build Script (PowerShell)
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "=== Building PeerLink Monorepo ===" -ForegroundColor Cyan

# 1. Dependency validation
Write-Host "1. Validating dependency boundaries..." -ForegroundColor Yellow
& "$PSScriptRoot/check-deps.ps1"

# 2. Proto generation
Write-Host "2. Generating Protocol Buffers..." -ForegroundColor Yellow
& "$PSScriptRoot/generate-proto.ps1"

# 3. Java modules build
Write-Host "3. Compiling Java Core & Desktop Node..." -ForegroundColor Yellow
mvn clean compile -B

# 4. Flutter analysis
Write-Host "4. Analyzing Flutter application..." -ForegroundColor Yellow
if (Test-Path "windows/app/flutter") {
    Push-Location "windows/app/flutter"
    flutter pub get
    flutter analyze --fatal-infos
    Pop-Location
}

Write-Host "=== PeerLink Monorepo Build Succeeded ===" -ForegroundColor Green
