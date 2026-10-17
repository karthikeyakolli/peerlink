# PeerLink Windows Desktop One-Click Launcher
[CmdletBinding()]
param(
    [switch]$SkipDaemon
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
Set-Location $repoRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  PeerLink Windows Desktop - One-Click Launcher" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Start Desktop Node Daemon if not already running
if (-not $SkipDaemon) {
    $daemonPort = 50051
    $isListening = Get-NetTCPConnection -LocalPort $daemonPort -ErrorAction SilentlyContinue
    if (-not $isListening) {
        Write-Host "Starting PeerLink Desktop Local Node daemon on port $daemonPort..." -ForegroundColor Yellow
        $daemonJar = Join-Path $repoRoot "desktop-node\target\desktop-node-0.1.0-SNAPSHOT.jar"
        if (Test-Path $daemonJar) {
            Start-Process -FilePath "java" -ArgumentList "-jar", "`"$daemonJar`"" -WindowStyle Minimized
        } else {
            Write-Host "Daemon JAR not found, starting via Maven..." -ForegroundColor Yellow
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "mvn.cmd -pl desktop-node exec:java -Dexec.mainClass=org.peerlink.desktop.runtime.DesktopNodeDaemon" -WindowStyle Minimized
        }
        Start-Sleep -Seconds 2
    } else {
        Write-Host "Desktop Local Node daemon is already active on port $daemonPort." -ForegroundColor Green
    }
}

# 2. Check Visual Studio C++ Compiler
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasVCC = $false
if (Test-Path $vsWhere) {
    $vsInstalls = & $vsWhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vsInstalls) {
        $hasVCC = $true
    }
}

$flutterBin = "flutter"
$appDir = Join-Path $repoRoot "windows\app\flutter"
Push-Location $appDir

if ($hasVCC) {
    Write-Host "Launching PeerLink Windows Native Desktop App..." -ForegroundColor Cyan
    & $flutterBin run -d windows
} else {
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "Note: Native Visual Studio C++ runner not installed." -ForegroundColor Yellow
    Write-Host "Running Flutter test suite and verification instead..." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Yellow
    & $flutterBin test
}

Pop-Location
