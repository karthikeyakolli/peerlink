$RepoRoot = Split-Path -Parent $PSScriptRoot

$srcFeatures = Join-Path $RepoRoot "windows\app\flutter\lib\features\*"
$srcDesign = Join-Path $RepoRoot "windows\app\flutter\lib\design_system\*"

$desktopTargets = @(
    "linux\app\flutter\lib",
    "macos\app\flutter\lib",
    "shared-source\canonical\flutter\lib"
)

foreach ($t in $desktopTargets) {
    $featDir = Join-Path $RepoRoot "$t\features"
    $designDir = Join-Path $RepoRoot "$t\design_system"
    if (-not (Test-Path $featDir)) { New-Item -ItemType Directory -Path $featDir -Force | Out-Null }
    if (-not (Test-Path $designDir)) { New-Item -ItemType Directory -Path $designDir -Force | Out-Null }
    Copy-Item $srcFeatures $featDir -Recurse -Force
    Copy-Item $srcDesign $designDir -Recurse -Force
    Write-Host "Synced features and design system to: $t"
}
