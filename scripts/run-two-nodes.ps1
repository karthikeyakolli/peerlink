# PeerLink Run Two Independent Local Nodes (Windows PowerShell)
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$java25Bin = "C:\Program Files\Microsoft\jdk-25.0.4.101-hotspot\bin\java.exe"
if (-not (Test-Path $java25Bin)) {
    $java25Bin = "java"
}

$shadedJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"
if (-not (Test-Path $shadedJar)) {
    Write-Host "Building desktop node shaded fat JAR..." -ForegroundColor Yellow
    $mavenBin = if (Test-Path "D:\tools\apache-maven-3.9.9\bin\mvn.cmd") { "D:\tools\apache-maven-3.9.9\bin\mvn.cmd" } else { "mvn" }
    $env:JAVA_HOME = "C:\Program Files\Java\jdk-21.0.12"
    $env:PATH = "C:\Program Files\Java\jdk-21.0.12\bin;D:\tools\apache-maven-3.9.9\bin;D:\tools\bin;" + $env:PATH
    & $mavenBin package -DskipTests=true
}

$dataDirA = Join-Path $repoRoot "data\nodeA"
$dataDirB = Join-Path $repoRoot "data\nodeB"
New-Item -ItemType Directory -Force -Path $dataDirA | Out-Null
New-Item -ItemType Directory -Force -Path $dataDirB | Out-Null

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "          Starting Two Independent Local Nodes            " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Start Node A on 50051
Write-Host "`nLaunching Node A (Port: 50051, Dir: $dataDirA)..." -ForegroundColor Yellow
$procA = Start-Process -FilePath $java25Bin -ArgumentList "-jar `"$shadedJar`" --port 50051 --data-dir `"$dataDirA`" --token dev-token-default" -PassThru -NoNewWindow

# Start Node B on 50052
Write-Host "Launching Node B (Port: 50052, Dir: $dataDirB)..." -ForegroundColor Yellow
$procB = Start-Process -FilePath $java25Bin -ArgumentList "-jar `"$shadedJar`" --port 50052 --data-dir `"$dataDirB`" --token dev-token-default" -PassThru -NoNewWindow

Start-Sleep -Seconds 3

# Verify connectivity to both
$dartBin = "D:\tools\flutter\bin\cache\dart-sdk\bin\dart.exe"
if (-not (Test-Path $dartBin)) {
    $dartBin = "dart"
}

Push-Location "apps\peerlink-app"
try {
    Write-Host "`n[1/2] Verifying Node A IPC..." -ForegroundColor Cyan
    & $dartBin run test/integration/live_node_proof.dart 50051 dev-token-default

    Write-Host "`n[2/2] Verifying Node B IPC..." -ForegroundColor Cyan
    & $dartBin run test/integration/live_node_proof.dart 50052 dev-token-default
} finally {
    Pop-Location
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "Both Node A (PID: $($procA.Id)) and Node B (PID: $($procB.Id)) are active!" -ForegroundColor Green
Write-Host "To stop both nodes, run:" -ForegroundColor Gray
Write-Host "  Stop-Process -Id $($procA.Id), $($procB.Id)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
