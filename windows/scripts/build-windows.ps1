# PeerLink Windows Application Build Script
# Builds the Windows Local Node daemon and Flutter Windows desktop application.

param (
    [switch]$SkipNode = $false,
    [switch]$SkipUi = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$windowsDir = Split-Path -Parent $scriptDir
$flutterDir = Join-Path $windowsDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Windows Application Build" -ForegroundColor Cyan
Write-Host " Base Directory: $windowsDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$buildSuccess = $true

# 1. Build Local Node (Java)
if (-not $SkipNode) {
    Write-Host "`n[1/2] Building Windows Local Node Daemon..." -ForegroundColor Cyan
    $mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
    if ($mvnCmd) {
        try {
            Push-Location $windowsDir
            Write-Host "Executing: mvn clean package -DskipTests=true -f pom.xml..." -ForegroundColor Gray
            & mvn clean package -DskipTests=true -f pom.xml
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Maven build failed with exit code $LASTEXITCODE."
                $buildSuccess = $false
            } else {
                Write-Host "Windows Local Node daemon built successfully." -ForegroundColor Green
            }
        } finally {
            Pop-Location
        }
    } else {
        # Check if pre-built desktop-node jar exists as portable fallback
        $repoRoot = Split-Path -Parent $windowsDir
        $existingJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"
        if (Test-Path $existingJar) {
            Write-Host "NOTE: mvn CLI is missing, but verified existing artifact found at: $existingJar" -ForegroundColor Yellow
        } else {
            Write-Host "BLOCKED: Maven (mvn) CLI is missing and no pre-built Local Node jar was found." -ForegroundColor Red
            $buildSuccess = $false
        }
    }
}

# 2. Build Flutter Desktop Application (Windows C++ Runner)
if (-not $SkipUi) {
    Write-Host "`n[2/2] Building Flutter Windows Desktop UI..." -ForegroundColor Cyan

    # Check Flutter
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $flutterCmd) {
        Write-Host "BLOCKED: Flutter SDK is not installed on PATH." -ForegroundColor Red
        Write-Host "         Cannot compile Windows Flutter desktop UI." -ForegroundColor Yellow
        $buildSuccess = $false
    } else {
        # Check Visual Studio Desktop C++ workload
        $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        $hasVCC = $false
        if (Test-Path $vsWhere) {
            $installs = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
            if ($installs) {
                $hasVCC = $true
            }
        }

        if (-not $hasVCC) {
            Write-Host "BLOCKED: Visual Studio 'Desktop development with C++' workload is not installed." -ForegroundColor Red
            Write-Host "         The Flutter Windows native runner executable cannot be compiled." -ForegroundColor Yellow
            $buildSuccess = $false
        } else {
            try {
                Push-Location $flutterDir
                Write-Host "Executing: flutter build windows in $flutterDir..." -ForegroundColor Gray
                & flutter build windows
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Flutter build windows failed with exit code $LASTEXITCODE."
                    $buildSuccess = $false
                } else {
                    Write-Host "Flutter Windows application built successfully." -ForegroundColor Green
                }
            } finally {
                Pop-Location
            }
        }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($buildSuccess) {
    Write-Host "Windows build completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Windows build BLOCKED or failed. See output above for required toolchains." -ForegroundColor Yellow
    exit 1
}
