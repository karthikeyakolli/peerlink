# PeerLink Platform Shared-Source Synchronization Tool (PowerShell)
param(
    [switch]$DryRun = $false,
    [string[]]$Platforms = @("windows", "linux", "macos", "android"),
    [string]$CanonicalDir = "shared-source/canonical",
    [switch]$VerboseOutput = $false
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoRoot

$CanonicalRoot = Join-Path $RepoRoot $CanonicalDir
if (-not (Test-Path $CanonicalRoot)) {
    throw "Canonical directory not found: $CanonicalRoot"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Shared-Source Synchronization Tool" -ForegroundColor Cyan
Write-Host " Canonical Source: $CanonicalDir" -ForegroundColor Cyan
Write-Host " Target Platforms: $($Platforms -join ', ')" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host " MODE: DRY-RUN (No files will be modified)" -ForegroundColor Yellow
}
Write-Host "==========================================================" -ForegroundColor Cyan

# Modules that are canonically managed
$SharedModules = @(
    "core",
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

$TotalCopied = 0
$TotalUpToDate = 0
$TotalConflicts = 0
$Report = @()

foreach ($Platform in $Platforms) {
    $PlatformRoot = Join-Path $RepoRoot $Platform
    if (-not (Test-Path $PlatformRoot)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $PlatformRoot -Force | Out-Null
        }
    }

    Write-Host "`nProcessing platform: $Platform..." -ForegroundColor Yellow

    # 1. Sync standard common modules
    foreach ($Module in $SharedModules) {
        $CanonicalModulePath = Join-Path $CanonicalRoot $Module
        $PlatformModulePath = Join-Path $PlatformRoot $Module

        if (Test-Path $CanonicalModulePath) {
            $CanonicalFiles = Get-ChildItem -Recurse -File $CanonicalModulePath

            foreach ($File in $CanonicalFiles) {
                $RelativePath = $File.FullName.Substring($CanonicalModulePath.Length).TrimStart('\', '/')
                $DestFile = Join-Path $PlatformModulePath $RelativePath
                $DestDir = Split-Path -Parent $DestFile

                $CanonicalHash = (Get-FileHash $File.FullName -Algorithm SHA256).Hash.ToLower()

                if (Test-Path $DestFile) {
                    $DestHash = (Get-FileHash $DestFile -Algorithm SHA256).Hash.ToLower()
                    if ($CanonicalHash -eq $DestHash) {
                        $Action = "UP-TO-DATE"
                        $TotalUpToDate++
                    } else {
                        # Divergence detected: Never silently overwrite platform modifications!
                        $Action = "DIVERGENCE"
                        $TotalConflicts++
                        Write-Host "  [DIVERGENCE/CONFLICT] $Module/$RelativePath (Canonical: $CanonicalHash vs Platform: $DestHash) - Platform file preserved!" -ForegroundColor Red
                    }
                } else {
                    $Action = "NEW"
                    $TotalCopied++
                    Write-Host "  [NEW] $Module/$RelativePath" -ForegroundColor Green
                    if (-not $DryRun) {
                        if (-not (Test-Path $DestDir)) {
                            New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
                        }
                        Copy-Item -Path $File.FullName -Destination $DestFile -Force
                    }
                }

                $Report += [PSCustomObject]@{
                    Platform = $Platform
                    Module = $Module
                    File = $RelativePath
                    Action = $Action
                    CanonicalHash = $CanonicalHash
                }
            }
        }
    }

    # 2. Sync Common Flutter application code into {platform}/app/flutter/
    $CanonicalFlutter = Join-Path $CanonicalRoot "flutter"
    $PlatformFlutter = Join-Path $PlatformRoot "app/flutter"

    if (Test-Path $CanonicalFlutter) {
        $FlutterFiles = Get-ChildItem -Recurse -File $CanonicalFlutter
        foreach ($File in $FlutterFiles) {
            $RelativePath = $File.FullName.Substring($CanonicalFlutter.Length).TrimStart('\', '/')
            $DestFile = Join-Path $PlatformFlutter $RelativePath
            $DestDir = Split-Path -Parent $DestFile

            $CanonicalHash = (Get-FileHash $File.FullName -Algorithm SHA256).Hash.ToLower()

            if (Test-Path $DestFile) {
                $DestHash = (Get-FileHash $DestFile -Algorithm SHA256).Hash.ToLower()
                if ($CanonicalHash -eq $DestHash) {
                    $Action = "UP-TO-DATE"
                    $TotalUpToDate++
                } else {
                    # Divergence detected: Never silently overwrite platform modifications!
                    $Action = "DIVERGENCE"
                    $TotalConflicts++
                    Write-Host "  [DIVERGENCE/CONFLICT] app/flutter/$RelativePath (Canonical: $CanonicalHash vs Platform: $DestHash) - Platform file preserved!" -ForegroundColor Red
                }
            } else {
                $Action = "NEW"
                $TotalCopied++
                Write-Host "  [NEW] app/flutter/$RelativePath" -ForegroundColor Green
                if (-not $DryRun) {
                    if (-not (Test-Path $DestDir)) {
                        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
                    }
                    Copy-Item -Path $File.FullName -Destination $DestFile -Force
                }
            }

            $Report += [PSCustomObject]@{
                Platform = $Platform
                Module = "app/flutter"
                File = $RelativePath
                Action = $Action
                CanonicalHash = $CanonicalHash
            }
        }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Synchronization Summary:" -ForegroundColor Cyan
Write-Host " Files Copied/Updated: $TotalCopied" -ForegroundColor $(if ($TotalCopied -gt 0) { "Green" } else { "Gray" })
Write-Host " Files Up-To-Date:     $TotalUpToDate" -ForegroundColor Gray
Write-Host " Conflicts Encountered: $TotalConflicts" -ForegroundColor $(if ($TotalConflicts -gt 0) { "Red" } else { "Green" })
Write-Host "==========================================================" -ForegroundColor Cyan

if ($TotalConflicts -gt 0) {
    exit 1
} else {
    exit 0
}
