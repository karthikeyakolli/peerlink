$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent
Set-Location $RepoRoot

$outDir = Join-Path $env:TEMP "phase16_test_out_$PID"
$argFile = Join-Path $env:TEMP "phase16_srcs_$PID.txt"

try {
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $modelSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\model\*.java" | ForEach-Object { $_.FullName }
    $capSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\capability\*.java" | ForEach-Object { $_.FullName }
    $compatSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\compatibility\*.java" | ForEach-Object { $_.FullName }
    $secSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\security\ScannerProvider.java", "core\src\main\java\org\peerlink\core\security\SecurityVerdict.java" | ForEach-Object { $_.FullName }
    $safetySrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\safety\*.java" | Where-Object { $_.Name -notmatch "EmergencyStop|NodeWatchdog" } | ForEach-Object { $_.FullName }
    $testSrcs = @(
        "core\src\test\java\org\peerlink\core\safety\Phase16StandaloneTestRunner.java"
    )

    $allSrcs = @($modelSrcs) + @($capSrcs) + @($compatSrcs) + @($secSrcs) + @($safetySrcs) + @($testSrcs)
    Set-Content -Path $argFile -Value ($allSrcs -join "`n")

    Write-Host "Compiling Phase 16 sources with javac..." -ForegroundColor Yellow
    & javac -d $outDir "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running Phase 16 Standalone Test Suite..." -ForegroundColor Yellow
    & java -cp $outDir org.peerlink.core.safety.Phase16StandaloneTestRunner
    if ($LASTEXITCODE -ne 0) {
        throw "Test execution failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    Remove-Item -Force $argFile -ErrorAction SilentlyContinue
}
