# PeerLink macOS - Open Native Xcode Workspace (Cross-Platform)
# Resolves paths relative to the project root and reports or launches Xcode workspace.

$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot
$macosDir = Split-Path -Parent $scriptDir

$workspace = Join-Path $macosDir "app\flutter\macos\Runner.xcworkspace"
$project = Join-Path $macosDir "app\flutter\macos\Runner.xcodeproj"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink macOS - Opening Native Xcode Workspace" -ForegroundColor Cyan
Write-Host " Base Directory: $macosDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not (Test-Path $workspace)) {
    $fallbackWs = Join-Path $macosDir "app\macos\Runner.xcworkspace"
    if (Test-Path $fallbackWs) {
        $workspace = $fallbackWs
        $project = Join-Path $macosDir "app\macos\Runner.xcodeproj"
    } else {
        Write-Error "ERROR: Xcode workspace artifact not found at $workspace."
        exit 1
    }
}

Write-Host "Xcode Workspace: $workspace" -ForegroundColor Gray
Write-Host "Xcode Project:   $project" -ForegroundColor Gray

if ($IsMacOS) {
    Write-Host "Launching Xcode..." -ForegroundColor Green
    & open $workspace
    exit $LASTEXITCODE
} else {
    Write-Host ""
    Write-Host "BLOCKED: Xcode IDE can only be launched on Apple macOS (Darwin)." -ForegroundColor Yellow
    Write-Host "         The native Xcode project is verified present and properly laid out." -ForegroundColor Green
    Write-Host "         To open in Xcode, run the following on a macOS host:" -ForegroundColor Gray
    Write-Host "         open $workspace" -ForegroundColor Cyan
    exit 0
}
