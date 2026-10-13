$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent
Set-Location $RepoRoot

$outDir = Join-Path $env:TEMP "phase14_test_out_$PID"
$argFile = Join-Path $env:TEMP "phase14_srcs_$PID.txt"

try {
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $syncSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\sync\*.java" | ForEach-Object { $_.FullName }
    $testSrcs = @(
        "core\src\test\java\org\peerlink\core\sync\Phase14StandaloneTestRunner.java"
    )

    $allSrcs = @($syncSrcs) + @($testSrcs)
    Set-Content -Path $argFile -Value ($allSrcs -join "`n")

    Write-Host "Compiling Phase 14 sources with javac..." -ForegroundColor Yellow
    & javac -d $outDir "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running Phase 14 Standalone Test Suite..." -ForegroundColor Yellow
    & java -cp $outDir org.peerlink.core.sync.Phase14StandaloneTestRunner
    if ($LASTEXITCODE -ne 0) {
        throw "Test execution failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    Remove-Item -Force $argFile -ErrorAction SilentlyContinue
}
