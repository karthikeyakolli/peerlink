# PeerLink Linux Run Script (Cross-Platform / Windows Host)
# Starts the Linux Local Node daemon and checks Linux UI execution status.

param (
    [int]$Port = 50051,
    [string]$DataDir = "data/node1",
    [string]$Token = "dev-token-default",
    [switch]$NodeOnly = $false,
    [switch]$UiOnly = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$linuxDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $linuxDir
$flutterDir = Join-Path $linuxDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Linux Application Launcher" -ForegroundColor Cyan
Write-Host " Base Directory: $linuxDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Locate Java Runtime
$javaBin = $null
if ($env:JAVA_HOME -and (Test-Path "$env:JAVA_HOME\bin\java.exe")) {
    $javaBin = "$env:JAVA_HOME\bin\java.exe"
} elseif (Get-Command java -ErrorAction SilentlyContinue) {
    $javaBin = "java"
} else {
    Write-Error "FATAL: Java runtime not found. Please install Java 21+ or set JAVA_HOME."
    exit 1
}

# Locate Local Node Jar
$nodeJar = $null
$localJar = Join-Path $linuxDir "target\peerlink-linux-node-0.1.0-SNAPSHOT.jar"
$shadedJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"

if (Test-Path $localJar) {
    $nodeJar = $localJar
} elseif (Test-Path $shadedJar) {
    $nodeJar = $shadedJar
}

if (-not $UiOnly) {
    if (-not $nodeJar) {
        Write-Error "Local Node JAR not found at $localJar or $shadedJar. Run build-linux.ps1 or build-linux.sh first."
        exit 1
    }

    $fullDataDir = Join-Path $linuxDir $DataDir
    if (-not (Test-Path $fullDataDir)) {
        New-Item -ItemType Directory -Force -Path $fullDataDir | Out-Null
    }

    Write-Host "`n=== Launching Linux Local Node Daemon ===" -ForegroundColor Cyan
    Write-Host "Runtime:   $javaBin" -ForegroundColor Gray
    Write-Host "JAR:       $nodeJar" -ForegroundColor Gray
    Write-Host "Port:      $Port" -ForegroundColor Gray
    Write-Host "Data Dir:  $fullDataDir" -ForegroundColor Gray
    Write-Host "Token:     [CONFIGURED]" -ForegroundColor Gray
    Write-Host "===========================================" -ForegroundColor Cyan

    if ($NodeOnly) {
        & $javaBin -jar $nodeJar --port $Port --data-dir $fullDataDir --token $Token
        exit $LASTEXITCODE
    } else {
        $nodeProcess = Start-Process -FilePath $javaBin -ArgumentList @("-jar", "`"$nodeJar`"", "--port", "$Port", "--data-dir", "`"$fullDataDir`"", "--token", "`"$Token`"") -PassThru
        Write-Host "Local Node daemon started in background (PID: $($nodeProcess.Id))." -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
}

if (-not $NodeOnly) {
    Write-Host "`n=== Launching Flutter Linux Desktop UI ===" -ForegroundColor Cyan
    # Check if WSL is available
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
        Write-Host "WSL detected. Launching Linux GTK app in WSL..." -ForegroundColor Green
        $wslLinuxDir = (& wsl.exe wslpath -u ($linuxDir -replace '\\', '/'))
        & wsl.exe bash -c "cd '$wslLinuxDir' && bash scripts/run-linux.sh --ui-only"
    } else {
        Write-Host "BLOCKED: Linux GTK UI cannot run natively on Windows host without WSL/WSLg or Linux machine." -ForegroundColor Yellow
        Write-Host "         Local Node daemon is active on port $Port, but Desktop UI requires Linux." -ForegroundColor Yellow
    }
}

exit 0
