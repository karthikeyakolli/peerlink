# PeerLink macOS Test Runner (Cross-Platform)
# Runs unit and integration tests for the macOS Local Node and Flutter desktop app.

param (
    [switch]$SkipNodeTests = $false,
    [switch]$SkipUiTests = $false
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$macosDir = Split-Path -Parent $scriptDir
$flutterDir = Join-Path $macosDir "app\flutter"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink macOS Test Execution" -ForegroundColor Cyan
Write-Host " Base Directory: $macosDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$testResults = @()
$hasFailure = $false

# 1. macOS Local Node Tests (JUnit 5)
if (-not $SkipNodeTests) {
    Write-Host "`n[1/2] Running macOS Local Node Unit & Integration Tests..." -ForegroundColor Cyan
    $mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
    if ($mvnCmd) {
        try {
            Push-Location $macosDir
            Write-Host "Executing: mvn test -f pom.xml..." -ForegroundColor Gray
            & mvn test -f pom.xml
            if ($LASTEXITCODE -ne 0) {
                $testResults += [PSCustomObject]@{ Suite = "Local Node (JUnit)"; Status = "FAILED"; Details = "Exit code $LASTEXITCODE" }
                $hasFailure = $true
            } else {
                $testResults += [PSCustomObject]@{ Suite = "Local Node (JUnit)"; Status = "PASSED"; Details = "All tests passed" }
            }
        } finally {
            Pop-Location
        }
    } else {
        $testResults += [PSCustomObject]@{ Suite = "Local Node (JUnit)"; Status = "BLOCKED"; Details = "Maven (mvn) CLI is missing" }
    }
}

# 2. macOS Flutter App Tests
if (-not $SkipUiTests) {
    Write-Host "`n[2/2] Running macOS Flutter Desktop Tests..." -ForegroundColor Cyan
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        try {
            Push-Location $flutterDir
            Write-Host "Executing: flutter test in $flutterDir..." -ForegroundColor Gray
            & flutter test
            if ($LASTEXITCODE -ne 0) {
                $testResults += [PSCustomObject]@{ Suite = "Flutter Desktop Tests"; Status = "FAILED"; Details = "Exit code $LASTEXITCODE" }
                $hasFailure = $true
            } else {
                $testResults += [PSCustomObject]@{ Suite = "Flutter Desktop Tests"; Status = "PASSED"; Details = "All widget and IPC tests passed" }
            }
        } finally {
            Pop-Location
        }
    } else {
        $testResults += [PSCustomObject]@{ Suite = "Flutter Desktop Tests"; Status = "BLOCKED"; Details = "Flutter SDK is not installed on PATH" }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Test Execution Summary" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$testResults | Format-Table -AutoSize -Property Suite, Status, Details

if ($hasFailure) {
    Write-Host "Test execution failed." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Test run completed (see individual status above)." -ForegroundColor Green
    exit 0
}
