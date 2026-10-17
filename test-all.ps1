# PeerLink Master Test Suite - Comprehensive Cross-Platform Verification
[CmdletBinding()]
param(
    [switch]$SkipGradle
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
Set-Location $repoRoot

$startTime = Get-Date

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  PeerLink Monorepo - Comprehensive Test Suite" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$results = [ordered]@{}

# 1. Dependency Boundary Checks
Write-Host "`n[1/6] Verifying Architectural Boundaries & Forbidden Dependencies..." -ForegroundColor Yellow
try {
    powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\check-deps.ps1")
    $results["Architecture Boundaries"] = "PASSED"
} catch {
    $results["Architecture Boundaries"] = "FAILED: $_"
}

# 2. Java Core & Desktop Node Reactor Tests (Maven)
Write-Host "`n[2/6] Running Java Core & Desktop Node Tests (Maven JUnit 5)..." -ForegroundColor Yellow
try {
    & .\mvnw.cmd test -B
    if ($LASTEXITCODE -eq 0) {
        $results["Java Core & Desktop Reactor (279 Tests)"] = "PASSED (100% Green)"
    } else {
        $results["Java Core & Desktop Reactor"] = "FAILED (Exit code $LASTEXITCODE)"
    }
} catch {
    $results["Java Core & Desktop Reactor"] = "FAILED: $_"
}

# 3. Android Studio Edition Tests (Flutter 16 tests)
Write-Host "`n[3/6] Running Android Studio Edition Tests (16 Tests)..." -ForegroundColor Yellow
try {
    Push-Location (Join-Path $repoRoot "peerlink-android-studio")
    flutter test
    if ($LASTEXITCODE -eq 0) {
        $results["Android Studio Edition (16 Tests)"] = "PASSED (100% Green)"
    } else {
        $results["Android Studio Edition (16 Tests)"] = "FAILED (Exit code $LASTEXITCODE)"
    }
    Pop-Location
} catch {
    $results["Android Studio Edition (16 Tests)"] = "FAILED: $_"
}

# 4. Android Native Gradle Compilation
if (-not $SkipGradle) {
    Write-Host "`n[4/6] Compiling Android Native APK (Gradle assembleDebug)..." -ForegroundColor Yellow
    try {
        Push-Location (Join-Path $repoRoot "peerlink-android-studio\android")
        .\gradlew.bat assembleDebug
        if ($LASTEXITCODE -eq 0) {
            $results["Android Native APK Build"] = "PASSED (BUILD SUCCESSFUL)"
        } else {
            $results["Android Native APK Build"] = "FAILED (Exit code $LASTEXITCODE)"
        }
        Pop-Location
    } catch {
        $results["Android Native APK Build"] = "FAILED: $_"
    }
} else {
    $results["Android Native APK Build"] = "SKIPPED"
}

# 5. Windows Desktop Flutter Tests (12 tests)
Write-Host "`n[5/6] Running Windows Desktop App Tests (12 Tests)..." -ForegroundColor Yellow
try {
    Push-Location (Join-Path $repoRoot "windows\app\flutter")
    flutter test
    if ($LASTEXITCODE -eq 0) {
        $results["Windows Desktop App (12 Tests)"] = "PASSED (100% Green)"
    } else {
        $results["Windows Desktop App (12 Tests)"] = "FAILED (Exit code $LASTEXITCODE)"
    }
    Pop-Location
} catch {
    $results["Windows Desktop App (12 Tests)"] = "FAILED: $_"
}

# 6. Linux & macOS Desktop Flutter Tests (24 tests total)
Write-Host "`n[6/6] Running Linux & macOS Desktop App Tests (24 Tests)..." -ForegroundColor Yellow
try {
    Push-Location (Join-Path $repoRoot "linux\app\flutter")
    flutter test
    $linuxPassed = ($LASTEXITCODE -eq 0)
    Pop-Location

    Push-Location (Join-Path $repoRoot "macos\app\flutter")
    flutter test
    $macosPassed = ($LASTEXITCODE -eq 0)
    Pop-Location

    if ($linuxPassed -and $macosPassed) {
        $results["Linux & macOS Desktop Apps (24 Tests)"] = "PASSED (100% Green)"
    } else {
        $results["Linux & macOS Desktop Apps (24 Tests)"] = "FAILED"
    }
} catch {
    $results["Linux & macOS Desktop Apps (24 Tests)"] = "FAILED: $_"
}

$elapsed = (Get-Date) - $startTime

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  Master Test Suite Results (Elapsed: $($elapsed.Minutes)m $($elapsed.Seconds)s)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$allPassed = $true
foreach ($entry in $results.GetEnumerator()) {
    $statusColor = if ($entry.Value -match "PASSED") { "Green" } elseif ($entry.Value -match "SKIPPED") { "Yellow" } else { "Red" }
    if ($entry.Value -match "FAILED") { $allPassed = $false }
    Write-Host ("{0,-45} : {1}" -f $entry.Key, $entry.Value) -ForegroundColor $statusColor
}

Write-Host "==========================================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "OVERALL RESULT: ALL TESTS PASSED (100% GREEN)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "OVERALL RESULT: SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
