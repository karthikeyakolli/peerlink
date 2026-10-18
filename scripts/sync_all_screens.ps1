# sync_all_screens.ps1
$ErrorActionPreference = 'Stop'

$screens = @(
  'features/devices/devices_screen.dart',
  'features/files/files_screen.dart',
  'features/spaces/spaces_screen.dart',
  'features/activity/activity_screen.dart',
  'features/search/search_screen.dart',
  'features/settings/settings_screen.dart'
)

$desktopTargets = @('linux/app/flutter', 'macos/app/flutter')

foreach ($t in $desktopTargets) {
  foreach ($s in $screens) {
    $src = "windows/app/flutter/lib/$s"
    $dst = "$t/lib/$s"
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    Copy-Item -Path $src -Destination $dst -Force
  }
  Copy-Item -Path 'windows/app/flutter/test/ephemeral_sharing_test.dart' -Destination "$t/test/ephemeral_sharing_test.dart" -Force
  Write-Host "Synced desktop screens to $t"
}

$mobileTargets = @('android/app/flutter')
foreach ($t in $mobileTargets) {
  foreach ($s in $screens) {
    $src = "peerlink-android-studio/lib/$s"
    $dst = "$t/lib/$s"
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    Copy-Item -Path $src -Destination $dst -Force
  }
  Copy-Item -Path 'windows/app/flutter/test/ephemeral_sharing_test.dart' -Destination "$t/test/ephemeral_sharing_test.dart" -Force
  Copy-Item -Path 'windows/app/flutter/test/ephemeral_sharing_test.dart' -Destination "peerlink-android-studio/test/ephemeral_sharing_test.dart" -Force
  Write-Host "Synced mobile screens to $t"
}

Write-Host "All screen synchronization complete."
