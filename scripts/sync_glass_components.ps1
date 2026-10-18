$RepoRoot = Split-Path -Parent $PSScriptRoot
$src1 = Join-Path $RepoRoot "peerlink-android-studio\lib\design_system\components\interactive_glass_card.dart"
$src2 = Join-Path $RepoRoot "peerlink-android-studio\lib\design_system\components\glass_container.dart"
$src3 = Join-Path $RepoRoot "peerlink-android-studio\lib\design_system\components\instant_beam_deck.dart"
$src4 = Join-Path $RepoRoot "peerlink-android-studio\lib\design_system\components\ephemeral_policy_modal.dart"
$src5 = Join-Path $RepoRoot "peerlink-android-studio\lib\design_system\components\burn_viewer_modal.dart"

$targets = @(
    "windows\app\flutter\lib\design_system\components",
    "linux\app\flutter\lib\design_system\components",
    "macos\app\flutter\lib\design_system\components",
    "android\app\flutter\lib\design_system\components",
    "shared-source\canonical\flutter\lib\design_system\components"
)

foreach ($t in $targets) {
    $dir = Join-Path $RepoRoot $t
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Copy-Item $src1 $dir -Force
    Copy-Item $src2 $dir -Force
    Copy-Item $src3 $dir -Force
    Copy-Item $src4 $dir -Force
    Copy-Item $src5 $dir -Force
    Write-Host "Synced components to: $t"
}
