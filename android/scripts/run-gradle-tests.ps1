# PeerLink Android Native / Gradle Test Runner
# Runs the Android host JUnit 4/5 unit tests and Kotlin platform bridge tests.

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$androidDir = Split-Path -Parent $scriptDir
$androidHostDir = Join-Path $androidDir "app\flutter\android"
if (-not (Test-Path $androidHostDir)) {
    $androidHostDir = Join-Path $androidDir "app\android"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Native / Gradle Test Suite" -ForegroundColor Cyan
Write-Host " Host Directory: $androidHostDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$gradlew = Join-Path $androidHostDir "gradlew.bat"
if (-not (Test-Path $gradlew)) {
    Write-Host "`nBLOCKED: Gradle wrapper (gradlew.bat) not found at $gradlew" -ForegroundColor Red
    exit 1
}

# Check if Java is available
$javaCmd = Get-Command java -ErrorAction SilentlyContinue
if (-not $javaCmd) {
    Write-Host "`nBLOCKED: Java runtime not found. Gradle execution requires JDK 17+." -ForegroundColor Red
    exit 1
}

# Check Flutter plugin resolution requirements
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Host "`nNOTE: Flutter SDK is not in PATH. Gradle may fail resolving dev.flutter plugins." -ForegroundColor Yellow
}

try {
    Push-Location $androidHostDir
    Write-Host "Executing: .\gradlew.bat testDebugUnitTest in $androidHostDir..." -ForegroundColor Gray
    & cmd.exe /c "gradlew.bat testDebugUnitTest"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nBLOCKED / FAILED: Gradle test execution failed with exit code $LASTEXITCODE." -ForegroundColor Red
        Write-Host "                  To run native tests, ensure Android SDK build-tools and Flutter SDK are installed." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "`nNative Android Gradle tests passed successfully!" -ForegroundColor Green
    exit 0
} finally {
    Pop-Location
}
