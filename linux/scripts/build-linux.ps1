# PeerLink Linux Application Build Script (Cross-Platform / Windows Host)
# Builds the Linux Local Node daemon and checks Linux Flutter desktop build prerequisites.

param (
    [switch]$SkipNode = $false,
    [switch]$SkipUi = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$linuxDir = Split-Path -Parent $scriptDir
$flutterDir = Join-Path $linuxDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Linux Application Build" -ForegroundColor Cyan
Write-Host " Base Directory: $linuxDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$buildSuccess = $true

# 1. Build Local Node (Java)
if (-not $SkipNode) {
    Write-Host "`n[1/2] Building Linux Local Node Daemon..." -ForegroundColor Cyan
    $mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
    if ($mvnCmd) {
        try {
            Push-Location $linuxDir
            Write-Host "Executing: mvn clean package -DskipTests=true -f pom.xml..." -ForegroundColor Gray
            & mvn clean package -DskipTests=true -f pom.xml
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Maven build failed with exit code $LASTEXITCODE."
                $buildSuccess = $false
            } else {
                Write-Host "Linux Local Node daemon built successfully." -ForegroundColor Green
            }
        } finally {
            Pop-Location
        }
    } else {
        $repoRoot = Split-Path -Parent $linuxDir
        $existingJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"
        if (Test-Path $existingJar) {
            Write-Host "NOTE: mvn CLI is missing, but verified existing artifact found at: $existingJar" -ForegroundColor Yellow
        } else {
            Write-Host "BLOCKED: Maven (mvn) CLI is missing and no pre-built Local Node jar was found." -ForegroundColor Red
            $buildSuccess = $false
        }
    }
}

# 2. Build Flutter Desktop Application (Linux GTK+ Runner)
if (-not $SkipUi) {
    Write-Host "`n[2/2] Checking Flutter Linux Desktop UI Build..." -ForegroundColor Cyan

    # Check if WSL is available to delegate the build
    $wslAvailable = $false
    try {
        $wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
        if ($wslCmd) {
            $rawOut = (& wsl.exe -l -v 2>&1) | Out-String
            $cleanOut = $rawOut -replace "`0", ""
            if ($LASTEXITCODE -eq 0 -and -not ($cleanOut -match "not installed" -or $cleanOut -match "no distributions installed")) {
                $wslAvailable = $true
            }
        }
    } catch {}

    if ($wslAvailable) {
        Write-Host "WSL detected. Delegating Flutter Linux build to WSL..." -ForegroundColor Cyan
        $wslLinuxDir = (& wsl.exe wslpath -u ($linuxDir -replace '\\', '/'))
        & wsl.exe bash -c "cd '$wslLinuxDir' && bash scripts/build-linux.sh --skip-node"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WSL Linux Flutter build failed." -ForegroundColor Red
            $buildSuccess = $false
        } else {
            Write-Host "WSL Linux Flutter application built successfully." -ForegroundColor Green
        }
    } else {
        Write-Host "BLOCKED: Linux GTK+ Flutter desktop applications cannot be cross-compiled natively from Windows." -ForegroundColor Red
        Write-Host "         The Flutter toolchain requires a native Linux host or WSL2 (Ubuntu/Debian) with GTK+ 3.0 headers." -ForegroundColor Yellow
        Write-Host "         On Windows, install WSL with: wsl --install" -ForegroundColor Yellow
        $buildSuccess = $false
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($buildSuccess) {
    Write-Host "Linux build completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Linux build BLOCKED or failed. See output above for required toolchains." -ForegroundColor Yellow
    exit 1
}
