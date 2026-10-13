$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent
Set-Location $RepoRoot

$outDir = Join-Path $env:TEMP "phase18_test_out_$PID"
$argFile = Join-Path $env:TEMP "phase18_srcs_$PID.txt"

try {
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $modelSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\model\*.java" | ForEach-Object { $_.FullName }
    $opSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\operation\*.java" | ForEach-Object { $_.FullName }
    $aiGwSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\ai\gateway\*.java" | ForEach-Object { $_.FullName }
    $aiModelSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\ai\model\*.java" | ForEach-Object { $_.FullName }
    $aiPolicySrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\ai\policy\*.java" | ForEach-Object { $_.FullName }
    $aiProviderSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\ai\provider\*.java" | ForEach-Object { $_.FullName }
    $aiServiceSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\ai\service\*.java" | ForEach-Object { $_.FullName }

    $testSrcs = @(
        "core\src\test\java\org\peerlink\core\ai\Phase18StandaloneTestRunner.java"
    )

    $allSrcs = @($modelSrcs) + @($opSrcs) + @($aiGwSrcs) + @($aiModelSrcs) + @($aiPolicySrcs) + @($aiProviderSrcs) + @($aiServiceSrcs) + @($testSrcs)

    Set-Content -Path $argFile -Value ($allSrcs -join "`n")

    Write-Host "Compiling Phase 18 sources with javac..." -ForegroundColor Yellow
    & javac -d $outDir "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running Phase 18 Standalone Test Suite..." -ForegroundColor Yellow
    & java -cp $outDir org.peerlink.core.ai.Phase18StandaloneTestRunner
    if ($LASTEXITCODE -ne 0) {
        throw "Test execution failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    Remove-Item -Force $argFile -ErrorAction SilentlyContinue
}
