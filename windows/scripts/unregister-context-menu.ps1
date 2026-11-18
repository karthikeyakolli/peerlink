# PeerLink Windows Explorer Context Menu Unregistration
$ErrorActionPreference = "SilentlyContinue"

$fileKey = "HKCU:\Software\Classes\*\shell\PeerLink"
$dirKey = "HKCU:\Software\Classes\Directory\shell\PeerLink"

Remove-Item -Path $fileKey -Recurse -Force | Out-Null
Remove-Item -Path $dirKey -Recurse -Force | Out-Null

Write-Host "PeerLink Windows Explorer context menu entries successfully removed." -ForegroundColor Green
