# PeerLink macOS Application Build Script (Cross-Platform)
# Builds the macOS Local Node daemon and checks macOS Flutter desktop build prerequisites.

param (
    [switch]$SkipNode = $false,
    [switch]$SkipUi = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$macosDir = Split-Path -Parent $scriptDir
$flutterDir = Join-Path $macosDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink macOS Application Build" -ForegroundColor Cyan
Write-Host " Base Directory: $macosDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$buildSuccess = $true

# 1. Build Local Node (Java)
if (-not $SkipNode) {
    Write-Host "`n[1/2] Building macOS Local Node Daemon..." -ForegroundColor Cyan
    $mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
    if ($mvnCmd) {
        try {
            Push-Location $macosDir
            Write-Host "Executing: mvn clean package -DskipTests=true -f pom.xml..." -ForegroundColor Gray
            & mvn clean package -DskipTests=true -f pom.xml
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Maven build failed with exit code $LASTEXITCODE."
                $buildSuccess = $false
            } else {
                Write-Host "macOS Local Node daemon built successfully." -ForegroundColor Green
            }
        } finally {
            Pop-Location
        }
    } else {
        $repoRoot = Split-Path -Parent $macosDir
        $existingJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"
        if (Test-Path $existingJar) {
            Write-Host "NOTE: mvn CLI is missing, but verified existing artifact found at: $existingJar" -ForegroundColor Yellow
        } else {
            Write-Host "BLOCKED: Maven (mvn) CLI is missing and no pre-built Local Node jar was found." -ForegroundColor Red
            $buildSuccess = $false
        }
    }
}

# 2. Build Flutter Desktop Application (macOS Runner)
if (-not $SkipUi) {
    Write-Host "`n[2/2] Checking Flutter macOS Desktop UI Build..." -ForegroundColor Cyan

    if (-not $IsMacOS) {
        Write-Host "BLOCKED: Building Flutter macOS application (.app bundle) requires an Apple macOS host with Xcode." -ForegroundColor Red
        Write-Host "         Cross-compiling macOS .app bundles natively from Windows or Linux is not supported." -ForegroundColor Yellow
        $buildSuccess = $false
    } else {
        $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
        if (-not $flutterCmd) {
            Write-Host "BLOCKED: Flutter SDK is not installed on PATH." -ForegroundColor Red
            $buildSuccess = $false
        } else {
            try {
                Push-Location $flutterDir
                Write-Host "Executing: flutter build macos --release in $flutterDir..." -ForegroundColor Gray
                & flutter build macos --release
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Flutter build macos failed with exit code $LASTEXITCODE."
                    $buildSuccess = $false
                } else {
                    Write-Host "Flutter macOS application built successfully." -ForegroundColor Green
                }
            } finally {
                Pop-Location
            }
        }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($buildSuccess) {
    Write-Host "macOS build completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "macOS build BLOCKED or failed. See output above for required toolchains." -ForegroundColor Yellow
    exit 1
}
