$ErrorActionPreference = "Stop"
$scratch = "C:\Users\OMEN\.gemini\antigravity-ide\brain\6c354964-d614-4ee9-a15e-1018cde86c29\scratch"
if (-not (Test-Path $scratch)) {
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
}
$dest = Join-Path $scratch "apps_backup_phase21.zip"
Write-Host "Creating backup archive at: $dest"
Compress-Archive -Path "apps" -DestinationPath $dest -Force
if (Test-Path $dest) {
    $size = (Get-Item $dest).Length
    Write-Host "Backup created successfully ($size bytes)" -ForegroundColor Green
} else {
    throw "Backup failed"
}
