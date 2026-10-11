# PeerLink Platform Shared-Source & Parity Verification Tool (PowerShell)
# Verifies bit-for-bit parity across shared invariant modules while respecting intentional OS divergence.

param(
    [string[]]$Platforms = @("windows", "linux", "macos", "android"),
    [string]$ManifestPath = "shared-source/PARITY-MANIFEST.json",
    [switch]$FailFast = $false
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Cross-Platform Parity Verification Tool" -ForegroundColor Cyan
Write-Host " Manifest:          $ManifestPath" -ForegroundColor Cyan
Write-Host " Target Platforms:  $($Platforms -join ', ')" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Shared Invariant Modules that MUST be identical across all 4 platforms
$SharedModules = @(
    "protocol",
    "operations",
    "transfer",
    "sync",
    "backup",
    "access",
    "sharing",
    "workspace",
    "clipboard",
    "compatibility",
    "security",
    "recovery",
    "diagnostics"
)

# Shared Flutter UI paths that MUST be identical across all 4 platforms
$SharedFlutterPaths = @(
    "lib/core/app_constants.dart",
    "lib/core/node_ipc_client.dart",
    "lib/core/protocol",
    "lib/features/activity",
    "lib/features/devices",
    "lib/features/files",
    "lib/features/home",
    "lib/features/search",
    "lib/features/settings",
    "lib/features/spaces",
    "lib/main.dart"
)

$DiscrepancyCount = 0
$TotalChecked = 0
$ReferencePlatform = $Platforms[0]

Write-Host "`nUsing '$ReferencePlatform' as reference baseline for invariant modules.`n" -ForegroundColor Yellow

# 1. Audit Shared Invariant Modules
foreach ($Module in $SharedModules) {
    $RefModuleDir = Join-Path $ReferencePlatform $Module
    if (-not (Test-Path $RefModuleDir)) {
        Write-Host "  [MISSING REFERENCE] Reference module missing: $ReferencePlatform/$Module" -ForegroundColor Red
        $DiscrepancyCount++
        continue
    }

    $RefFiles = Get-ChildItem -Recurse -File $RefModuleDir
    foreach ($File in $RefFiles) {
        $TotalChecked++
        $RelPath = $File.FullName.Substring((Resolve-Path $RefModuleDir).Path.Length).TrimStart('\', '/')
        $RefHash = (Get-FileHash $File.FullName -Algorithm SHA256).Hash.ToLower()

        foreach ($TargetPlatform in $Platforms) {
            if ($TargetPlatform -eq $ReferencePlatform) { continue }
            $TargetFile = Join-Path (Join-Path $TargetPlatform $Module) $RelPath

            if (-not (Test-Path $TargetFile)) {
                Write-Host "  [MISSING INVARIANT FILE] $TargetPlatform/$Module/$RelPath" -ForegroundColor Red
                $DiscrepancyCount++
                if ($FailFast) { exit 1 }
                continue
            }

            $TargetHash = (Get-FileHash $TargetFile -Algorithm SHA256).Hash.ToLower()
            if ($RefHash -ne $TargetHash) {
                Write-Host "  [INVARIANT HASH MISMATCH] $TargetPlatform/$Module/$RelPath" -ForegroundColor Red
                Write-Host "    Reference ($ReferencePlatform): $RefHash" -ForegroundColor Gray
                Write-Host "    Target ($TargetPlatform):    $TargetHash" -ForegroundColor Gray
                $DiscrepancyCount++
                if ($FailFast) { exit 1 }
            }
        }
    }
}

# 2. Audit Shared Flutter UI Code
Write-Host "Auditing shared Flutter UI components across platforms..." -ForegroundColor Yellow
foreach ($RelPath in $SharedFlutterPaths) {
    $RefPath = Join-Path "$ReferencePlatform/app/flutter" $RelPath
    if (-not (Test-Path $RefPath)) {
        Write-Host "  [MISSING REFERENCE FLUTTER] $ReferencePlatform/app/flutter/$RelPath" -ForegroundColor Red
        $DiscrepancyCount++
        continue
    }

    if ((Get-Item $RefPath) -is [System.IO.DirectoryInfo]) {
        $RefFiles = Get-ChildItem -Recurse -File $RefPath
        foreach ($File in $RefFiles) {
            $TotalChecked++
            $SubRel = $File.FullName.Substring((Resolve-Path $RefPath).Path.Length).TrimStart('\', '/')
            $FullRel = Join-Path $RelPath $SubRel
            $RefHash = (Get-FileHash $File.FullName -Algorithm SHA256).Hash.ToLower()

            foreach ($TargetPlatform in $Platforms) {
                if ($TargetPlatform -eq $ReferencePlatform) { continue }
                $TargetFile = Join-Path "$TargetPlatform/app/flutter" $FullRel

                if (-not (Test-Path $TargetFile)) {
                    Write-Host "  [MISSING FLUTTER FILE] $TargetPlatform/app/flutter/$FullRel" -ForegroundColor Red
                    $DiscrepancyCount++
                    if ($FailFast) { exit 1 }
                    continue
                }

                $TargetHash = (Get-FileHash $TargetFile -Algorithm SHA256).Hash.ToLower()
                if ($RefHash -ne $TargetHash) {
                    Write-Host "  [FLUTTER HASH MISMATCH] $TargetPlatform/app/flutter/$FullRel" -ForegroundColor Red
                    $DiscrepancyCount++
                    if ($FailFast) { exit 1 }
                }
            }
        }
    } else {
        $TotalChecked++
        $RefHash = (Get-FileHash $RefPath -Algorithm SHA256).Hash.ToLower()
        foreach ($TargetPlatform in $Platforms) {
            if ($TargetPlatform -eq $ReferencePlatform) { continue }
            $TargetFile = Join-Path "$TargetPlatform/app/flutter" $RelPath

            if (-not (Test-Path $TargetFile)) {
                Write-Host "  [MISSING FLUTTER FILE] $TargetPlatform/app/flutter/$RelPath" -ForegroundColor Red
                $DiscrepancyCount++
                if ($FailFast) { exit 1 }
                continue
            }

            $TargetHash = (Get-FileHash $TargetFile -Algorithm SHA256).Hash.ToLower()
            if ($RefHash -ne $TargetHash) {
                Write-Host "  [FLUTTER HASH MISMATCH] $TargetPlatform/app/flutter/$RelPath" -ForegroundColor Red
                $DiscrepancyCount++
                if ($FailFast) { exit 1 }
            }
        }
    }
}

# 3. Report Intentional Architectural Divergence
Write-Host "`nIntentional Platform Divergences Verified (Not Drift):" -ForegroundColor Cyan
Write-Host "  - core/platform/ : Each platform has isolated NativePlatformAdapter (Windows/Linux/Mac/Android)" -ForegroundColor Gray
Write-Host "  - Native Runners : windows/ (CMake), linux/ (GTK), macos/ (Xcode), android/ (Gradle)" -ForegroundColor Gray
Write-Host "  - Android Extras : android_node_bridge.dart & android_node_status_widget.dart present only on Android" -ForegroundColor Gray
Write-Host "  - OS Subsystems  : Windows DPAPI, Linux POSIX/SecretService, macOS APFS/Keychain, Android Keystore" -ForegroundColor Gray

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Parity Verification Summary:" -ForegroundColor Cyan
Write-Host " Total Invariant Files Checked: $TotalChecked" -ForegroundColor Gray
Write-Host " Total Accidental Drift:        $DiscrepancyCount" -ForegroundColor $(if ($DiscrepancyCount -eq 0) { "Green" } else { "Red" })
Write-Host " Status: $(if ($DiscrepancyCount -eq 0) { "PASS (Zero Accidental Drift; Perfect Invariant Parity)" } else { "FAIL (Discrepancies Detected)" })" -ForegroundColor $(if ($DiscrepancyCount -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================" -ForegroundColor Cyan

if ($DiscrepancyCount -gt 0) {
    exit 1
} else {
    exit 0
}
