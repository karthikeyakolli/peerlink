# PeerLink Developer Environment Setup (PowerShell)
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "=== Setting up PeerLink Developer Environment ===" -ForegroundColor Cyan

# 1. Check Java
Write-Host "Checking Java version..." -ForegroundColor Yellow
try {
    $javaVer = java -version 2>&1 | Out-String
    Write-Host $javaVer
} catch {
    Write-Warning "Java is not installed or not in PATH."
}

# 2. Check Maven
Write-Host "Checking Maven..." -ForegroundColor Yellow
try {
    mvn -v
} catch {
    Write-Warning "Maven is not installed or not in PATH."
}

# 3. Check Protoc
Write-Host "Checking Protoc..." -ForegroundColor Yellow
try {
    protoc --version
} catch {
    Write-Warning "protoc is not installed or not in PATH."
}

# 4. Check Flutter
Write-Host "Checking Flutter..." -ForegroundColor Yellow
try {
    flutter --version
} catch {
    Write-Warning "Flutter is not installed or not in PATH."
}

# 5. Generate Protocol Buffers
Write-Host "Generating Protobuf bindings..." -ForegroundColor Cyan
if (Test-Path "scripts/generate-proto.ps1") {
    & "$PSScriptRoot/generate-proto.ps1"
}

# 6. Install Flutter dependencies
Write-Host "Installing Flutter dependencies..." -ForegroundColor Cyan
if (Test-Path "windows/app/flutter") {
    Push-Location "windows/app/flutter"
    flutter pub get
    Pop-Location
}

# 7. Check architectural boundaries
Write-Host "Verifying architectural boundaries..." -ForegroundColor Cyan
& "$PSScriptRoot/check-deps.ps1"

Write-Host "=== PeerLink Environment Setup Completed ===" -ForegroundColor Green
