$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent
Set-Location $RepoRoot

$outDir = Join-Path $env:TEMP "phase17_test_out_$PID"
$argFile = Join-Path $env:TEMP "phase17_srcs_$PID.txt"

try {
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $modelSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\model\*.java" | ForEach-Object { $_.FullName }
    $capSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\capability\*.java" | ForEach-Object { $_.FullName }
    $compatSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\compatibility\*.java" | ForEach-Object { $_.FullName }
    $secSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\security\ScannerProvider.java", "core\src\main\java\org\peerlink\core\security\SecurityVerdict.java" | ForEach-Object { $_.FullName }
    $safetySrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\safety\*.java" | Where-Object { $_.Name -notmatch "EmergencyStop|NodeWatchdog" } | ForEach-Object { $_.FullName }
    $clipSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\collaboration\clipboard\*.java" | ForEach-Object { $_.FullName }
    $wsCollabSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\collaboration\workspace\*.java" | ForEach-Object { $_.FullName }
    $wsSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\workspace\*.java" | ForEach-Object { $_.FullName }
    $platSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\platform\*.java" | ForEach-Object { $_.FullName }
    $winSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\platform\windows\*.java" | ForEach-Object { $_.FullName }
    $lxSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\platform\linux\*.java" | ForEach-Object { $_.FullName }
    $macSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\platform\macos\*.java" | ForEach-Object { $_.FullName }
    $andPlatSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\platform\android\*.java" | ForEach-Object { $_.FullName }
    $fsSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\filesystem\PeerFileHandle.java", "core\src\main\java\org\peerlink\core\filesystem\PeerFileProvider.java" | ForEach-Object { $_.FullName }
    $andCoreSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\android\AndroidNodeContext.java", "core\src\main\java\org\peerlink\core\android\AndroidBackgroundPolicy.java", "core\src\main\java\org\peerlink\core\android\AndroidStorageAbstraction.java" | ForEach-Object { $_.FullName }

    $testSrcs = @(
        "core\src\test\java\org\peerlink\core\platform\Phase17StandaloneTestRunner.java"
    )

    $allSrcs = @($modelSrcs) + @($capSrcs) + @($compatSrcs) + @($secSrcs) + @($safetySrcs) + `
               @($clipSrcs) + @($wsCollabSrcs) + @($wsSrcs) + @($platSrcs) + @($winSrcs) + `
               @($lxSrcs) + @($macSrcs) + @($andPlatSrcs) + @($fsSrcs) + @($andCoreSrcs) + @($testSrcs)

    Set-Content -Path $argFile -Value ($allSrcs -join "`n")

    Write-Host "Compiling Phase 17 sources with javac..." -ForegroundColor Yellow
    & javac -d $outDir "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running Phase 17 Standalone Test Suite..." -ForegroundColor Yellow
    & java -cp $outDir org.peerlink.core.platform.Phase17StandaloneTestRunner
    if ($LASTEXITCODE -ne 0) {
        throw "Test execution failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    Remove-Item -Force $argFile -ErrorAction SilentlyContinue
}
