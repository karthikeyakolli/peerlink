# PeerLink Windows Dependency Resolution Script
# Resolves project-local dependencies for the Windows Local Node and Flutter app.

param (
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$windowsDir = Split-Path -Parent $scriptDir
$flutterDir = Join-Path $windowsDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Windows Dependency Resolution" -ForegroundColor Cyan
Write-Host " Base Directory: $windowsDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$allSucceeded = $true

# 1. Resolve Java / Maven Dependencies
Write-Host "`n[1/2] Resolving Windows Local Node Maven Dependencies..." -ForegroundColor Cyan
$mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
if ($mvnCmd) {
    try {
        Push-Location $windowsDir
        Write-Host "Executing: mvn dependency:resolve..." -ForegroundColor Gray
        & mvn dependency:resolve -f pom.xml
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Maven dependency resolution failed with exit code $LASTEXITCODE."
            $allSucceeded = $false
        } else {
            Write-Host "Maven dependencies resolved successfully." -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "WARN: Maven (mvn) CLI is not in PATH." -ForegroundColor Yellow
    Write-Host "      Java local dependencies cannot be resolved automatically." -ForegroundColor Yellow
    $allSucceeded = $false
}

# 2. Resolve Flutter Dart Dependencies
Write-Host "`n[2/2] Resolving Windows Flutter UI Dependencies..." -ForegroundColor Cyan
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    try {
        Push-Location $flutterDir
        Write-Host "Executing: flutter pub get in $flutterDir..." -ForegroundColor Gray
        & flutter pub get
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Flutter pub get failed with exit code $LASTEXITCODE."
            $allSucceeded = $false
        } else {
            Write-Host "Flutter dependencies resolved successfully." -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "BLOCKED: Flutter SDK is not installed on PATH." -ForegroundColor Yellow
    Write-Host "         Flutter pub get cannot be executed for $flutterDir" -ForegroundColor Yellow
    $allSucceeded = $false
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($allSucceeded) {
    Write-Host "All project-local dependencies resolved successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Dependency resolution incomplete or BLOCKED due to missing toolchain(s)." -ForegroundColor Yellow
    exit 1
}
