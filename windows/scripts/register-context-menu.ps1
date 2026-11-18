# PeerLink Windows Explorer Context Menu Registration
param(
    [string]$ExePath = ""
)

$ErrorActionPreference = "Stop"

if (-not $ExePath) {
    # Resolve default build/dist locations
    $candidates = @(
        (Join-Path $PSScriptRoot "..\..\dist\windows\bin\peerlink.exe"),
        (Join-Path $PSScriptRoot "..\build\runner\Release\peerlink.exe"),
        (Join-Path $PSScriptRoot "..\..\build\windows\x64\runner\Release\peerlink.exe")
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) {
            $ExePath = (Resolve-Path $cand).Path
            break
        }
    }
}

if (-not $ExePath -or -not (Test-Path $ExePath)) {
    Write-Error "Could not find peerlink.exe. Please build the application first or pass -ExePath '<path\to\peerlink.exe>'."
    exit 1
}

$resolvedExe = (Resolve-Path $ExePath).Path
Write-Host "Registering PeerLink context menu for: $resolvedExe" -ForegroundColor Cyan

# 1. Right-click on any file
$fileKey = "HKCU:\Software\Classes\*\shell\PeerLink"
New-Item -Path $fileKey -Force | Out-Null
Set-ItemProperty -Path $fileKey -Name "(Default)" -Value "Send with PeerLink"
Set-ItemProperty -Path $fileKey -Name "Icon" -Value "`"$resolvedExe`",0"
$fileCmdKey = "$fileKey\command"
New-Item -Path $fileCmdKey -Force | Out-Null
Set-ItemProperty -Path $fileCmdKey -Name "(Default)" -Value "`"$resolvedExe`" `"%1`""

# 2. Right-click on any folder
$dirKey = "HKCU:\Software\Classes\Directory\shell\PeerLink"
New-Item -Path $dirKey -Force | Out-Null
Set-ItemProperty -Path $dirKey -Name "(Default)" -Value "Send folder with PeerLink"
Set-ItemProperty -Path $dirKey -Name "Icon" -Value "`"$resolvedExe`",0"
$dirCmdKey = "$dirKey\command"
New-Item -Path $dirCmdKey -Force | Out-Null
Set-ItemProperty -Path $dirCmdKey -Name "(Default)" -Value "`"$resolvedExe`" `"%1`""

Write-Host "PeerLink Windows Explorer context menu successfully registered in current user registry (no admin required)!" -ForegroundColor Green
