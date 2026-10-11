# PeerLink macOS Run Script (Cross-Platform)
# Starts the macOS Local Node daemon and checks macOS UI execution status.

param (
    [int]$Port = 50051,
    [string]$DataDir = "data/node1",
    [string]$Token = "dev-token-default",
    [switch]$NodeOnly = $false,
    [switch]$UiOnly = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$macosDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $macosDir
$flutterDir = Join-Path $macosDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink macOS Application Launcher" -ForegroundColor Cyan
Write-Host " Base Directory: $macosDir" -ForegroundColor Cyan
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
$localJar = Join-Path $macosDir "target\peerlink-macos-node-0.1.0-SNAPSHOT.jar"
$shadedJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"

if (Test-Path $localJar) {
    $nodeJar = $localJar
} elseif (Test-Path $shadedJar) {
    $nodeJar = $shadedJar
}

if (-not $UiOnly) {
    if (-not $nodeJar) {
        Write-Error "Local Node JAR not found at $localJar or $shadedJar. Run build-macos.ps1 or build-macos.sh first."
        exit 1
    }

    $fullDataDir = Join-Path $macosDir $DataDir
    if (-not (Test-Path $fullDataDir)) {
        New-Item -ItemType Directory -Force -Path $fullDataDir | Out-Null
    }

    Write-Host "`n=== Launching macOS Local Node Daemon ===" -ForegroundColor Cyan
    Write-Host "Runtime:   $javaBin" -ForegroundColor Gray
    Write-Host "JAR:       $nodeJar" -ForegroundColor Gray
    Write-Host "Port:      $Port" -ForegroundColor Gray
    Write-Host "Data Dir:  $fullDataDir" -ForegroundColor Gray
    Write-Host "Token:     [CONFIGURED]" -ForegroundColor Gray
    Write-Host "=========================================" -ForegroundColor Cyan

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
    Write-Host "`n=== Launching Flutter macOS Desktop UI ===" -ForegroundColor Cyan
    if ($IsMacOS) {
        $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
        if ($flutterCmd) {
            try {
                Push-Location $flutterDir
                & flutter run -d macos
            } finally {
                Pop-Location
            }
        } else {
            Write-Host "BLOCKED: Flutter SDK is not installed on PATH." -ForegroundColor Yellow
        }
    } else {
        Write-Host "BLOCKED: macOS Cocoa/Flutter UI (.app bundle) cannot run on Windows/Linux host." -ForegroundColor Yellow
        Write-Host "         Local Node daemon is active on port $Port, but Desktop UI requires macOS." -ForegroundColor Yellow
    }
}

exit 0
