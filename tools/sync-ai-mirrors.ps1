$RepoRoot = $PSScriptRoot | Split-Path -Parent
Set-Location $RepoRoot

$targets = @(
    "shared-source/canonical/core/ai",
    "windows/core/ai",
    "windows/src/main/java/org/peerlink/core/ai",
    "linux/core/ai",
    "linux/src/main/java/org/peerlink/core/ai",
    "macos/core/ai",
    "macos/src/main/java/org/peerlink/core/ai",
    "android/core/ai",
    "android/src/main/java/org/peerlink/core/ai"
)

foreach ($target in $targets) {
    if (Test-Path $target) {
        Write-Host "Syncing to $target"
        Copy-Item -Path "core/src/main/java/org/peerlink/core/ai/*" -Destination $target -Recurse -Force
    }
}

$testTargets = @(
    "windows/src/test/java/org/peerlink/core/ai",
    "linux/src/test/java/org/peerlink/core/ai",
    "macos/src/test/java/org/peerlink/core/ai"
)
foreach ($tt in $testTargets) {
    if (Test-Path $tt) {
        Write-Host "Syncing test runner to $tt"
        Copy-Item -Path "core/src/test/java/org/peerlink/core/ai/Phase18StandaloneTestRunner.java" -Destination $tt -Force
    }
}

Write-Host "AI mirrors sync complete."
