# PeerLink Windows Run Script
# Starts the Windows Local Node daemon and optionally launches the Windows desktop UI.

param (
    [int]$Port = 50051,
    [string]$DataDir = "data/node1",
    [string]$Token = "dev-token-default",
    [switch]$NodeOnly = $false,
    [switch]$UiOnly = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$windowsDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $windowsDir
$flutterDir = Join-Path $windowsDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Windows Application Launcher" -ForegroundColor Cyan
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
$localJar = Join-Path $windowsDir "target\peerlink-windows-node-0.1.0-SNAPSHOT.jar"
$shadedJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"

if (Test-Path $localJar) {
    $nodeJar = $localJar
} elseif (Test-Path $shadedJar) {
    $nodeJar = $shadedJar
}

if (-not $UiOnly) {
    if (-not $nodeJar) {
        Write-Error "Local Node JAR not found at $localJar or $shadedJar. Run build-windows.ps1 first."
        exit 1
    }

    $fullDataDir = Join-Path $windowsDir $DataDir
    if (-not (Test-Path $fullDataDir)) {
        New-Item -ItemType Directory -Force -Path $fullDataDir | Out-Null
    }

    Write-Host "`n=== Launching Windows Local Node Daemon ===" -ForegroundColor Cyan
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
        # Start Local Node in background process for full application session
        $nodeProcess = Start-Process -FilePath $javaBin -ArgumentList @("-jar", "`"$nodeJar`"", "--port", "$Port", "--data-dir", "`"$fullDataDir`"", "--token", "`"$Token`"") -PassThru
        Write-Host "Local Node daemon started in background (PID: $($nodeProcess.Id))." -ForegroundColor Green

        # Wait briefly for daemon startup
        Start-Sleep -Seconds 2
    }
}

if (-not $NodeOnly) {
    Write-Host "`n=== Launching Flutter Windows Desktop UI ===" -ForegroundColor Cyan
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        try {
            Push-Location $flutterDir
            Write-Host "Starting Flutter Windows app..." -ForegroundColor Green
            & flutter run -d windows
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "BLOCKED: Flutter SDK is not installed on PATH." -ForegroundColor Yellow
        Write-Host "         Local Node daemon is active on port $Port, but Desktop UI cannot run without Flutter." -ForegroundColor Yellow
        exit 0
    }
}

exit 0
