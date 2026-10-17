# PeerLink Complete Local Development Startup Script (Windows PowerShell)
param (
    [int]$Port = 50051,
    [string]$Token = "dev-token-default"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "                PeerLink Windows Local Run                " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check prerequisites
& "$PSScriptRoot\check-environment.ps1"

# 2. Check protocol code generation
$javaOut = Join-Path $repoRoot "protocol\generated-java\org\peerlink\protocol\v1"
if (-not (Test-Path $javaOut)) {
    Write-Host ""
    Write-Host "Generating protocol buffers..." -ForegroundColor Yellow
    & "$PSScriptRoot\generate-proto.ps1"
}

# 3. Check Java Local Node Shaded Jar
$shadedJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"
if (-not (Test-Path $shadedJar)) {
    Write-Host ""
    Write-Host "Building Java Desktop Local Node shaded fat JAR..." -ForegroundColor Yellow
    $mavenBin = if (Test-Path "D:\tools\apache-maven-3.9.9\bin\mvn.cmd") { "D:\tools\apache-maven-3.9.9\bin\mvn.cmd" } else { "mvn" }
    $env:JAVA_HOME = "C:\Program Files\Java\jdk-21.0.12"
    $env:PATH = "C:\Program Files\Java\jdk-21.0.12\bin;D:\tools\apache-maven-3.9.9\bin;D:\tools\bin;" + $env:PATH
    & $mavenBin package -DskipTests=true
}

# 4. Start Java Local Node on Java 25
$java25Bin = "C:\Program Files\Microsoft\jdk-25.0.4.101-hotspot\bin\java.exe"
if (-not (Test-Path $java25Bin)) {
    $java25Bin = "java"
}

$dataDir = Join-Path $repoRoot "data\node1"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
}

Write-Host ""
Write-Host "[Step 1] Starting Java 25 Local Node Daemon on port $Port..." -ForegroundColor Cyan
$nodeProcess = Start-Process -FilePath $java25Bin -ArgumentList "-jar `"$shadedJar`" --port $Port --data-dir `"$dataDir`" --token $Token" -PassThru -NoNewWindow

# Wait for node to bind port
Write-Host "Waiting for Local Node IPC server on 127.0.0.1:$Port..." -ForegroundColor Yellow
$started = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect("127.0.0.1", $Port)
        $tcpClient.Close()
        $started = $true
        break
    } catch {}
}

if (-not $started) {
    Write-Error "Local Node failed to bind port $Port within timeout."
}

$nodePid = $nodeProcess.Id
Write-Host "Local Node is RUNNING on 127.0.0.1:$Port (PID: $nodePid)" -ForegroundColor Green

# 5. Run Live Flutter/Dart IPC Handshake Verification
Write-Host ""
Write-Host "[Step 2] Verifying Flutter / Java Local Node IPC Communication..." -ForegroundColor Cyan
$dartBin = "D:\tools\flutter\bin\cache\dart-sdk\bin\dart.exe"
if (-not (Test-Path $dartBin)) {
    $dartBin = "dart"
}

Push-Location "windows\app\flutter"
try {
    & $dartBin run test/integration/live_node_proof.dart $Port $Token
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "PeerLink Windows Local Run: ACTIVE AND VERIFIED" -ForegroundColor Green
Write-Host "Local Node PID: $nodePid (Listening on port $Port)" -ForegroundColor Green
Write-Host "Data Directory: $dataDir" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "To stop the running node, run: Stop-Process -Id $nodePid" -ForegroundColor Yellow
