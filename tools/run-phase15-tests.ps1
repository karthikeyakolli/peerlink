$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent
Set-Location $RepoRoot

$outDir = Join-Path $env:TEMP "phase15_test_out_$PID"
$argFile = Join-Path $env:TEMP "phase15_srcs_$PID.txt"

try {
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $modelSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\model\*.java" | ForEach-Object { $_.FullName }
    $backupSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\backup\*.java" | ForEach-Object { $_.FullName }
    $testSrcs = @(
        "core\src\test\java\org\peerlink\core\backup\Phase15StandaloneTestRunner.java"
    )

    $allSrcs = @($modelSrcs) + @($backupSrcs) + @($testSrcs)
    Set-Content -Path $argFile -Value ($allSrcs -join "`n")

    Write-Host "Compiling Phase 15 sources with javac..." -ForegroundColor Yellow
    & javac -d $outDir "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running Phase 15 Standalone Test Suite..." -ForegroundColor Yellow
    & java -cp $outDir org.peerlink.core.backup.Phase15StandaloneTestRunner
    if ($LASTEXITCODE -ne 0) {
        throw "Test execution failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    Remove-Item -Force $argFile -ErrorAction SilentlyContinue
}
