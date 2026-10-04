# PeerLink Run Java Local Node Script (Windows PowerShell)
param (
    [int]$Port = 50051,
    [string]$DataDir = "data/node1",
    [string]$Token = "dev-token-default"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$java25Bin = "C:\Program Files\Microsoft\jdk-25.0.4.101-hotspot\bin\java.exe"
if (-not (Test-Path $java25Bin)) {
    if (Get-Command java -ErrorAction SilentlyContinue) {
        $java25Bin = "java"
    } else {
        Write-Error "Java runtime not found. Please install Microsoft OpenJDK 25."
    }
}

$shadedJar = Join-Path $repoRoot "desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"

if (-not (Test-Path $shadedJar)) {
    Write-Host "Shaded fat jar not found. Building desktop node..." -ForegroundColor Yellow
    $mavenBin = if (Test-Path "D:\tools\apache-maven-3.9.9\bin\mvn.cmd") { "D:\tools\apache-maven-3.9.9\bin\mvn.cmd" } else { "mvn" }
    $env:JAVA_HOME = "C:\Program Files\Java\jdk-21.0.12"
    $env:PATH = "C:\Program Files\Java\jdk-21.0.12\bin;D:\tools\apache-maven-3.9.9\bin;D:\tools\bin;" + $env:PATH
    & $mavenBin package -DskipTests=true
}

$fullDataDir = Join-Path $repoRoot $DataDir
if (-not (Test-Path $fullDataDir)) {
    New-Item -ItemType Directory -Force -Path $fullDataDir | Out-Null
}

Write-Host "=== Starting PeerLink Local Node on Java 25 ===" -ForegroundColor Cyan
Write-Host "Runtime:   $java25Bin" -ForegroundColor Gray
Write-Host "Port:      $Port" -ForegroundColor Gray
Write-Host "Data Dir:  $fullDataDir" -ForegroundColor Gray
Write-Host "Token:     $Token" -ForegroundColor Gray
Write-Host "=============================================" -ForegroundColor Cyan

& $java25Bin -jar $shadedJar --port $Port --data-dir $fullDataDir --token $Token
