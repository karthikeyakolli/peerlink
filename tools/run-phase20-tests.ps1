$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent
Set-Location $RepoRoot

$outDir = Join-Path $env:TEMP "phase20_test_out_$PID"
$argFile = Join-Path $env:TEMP "phase20_srcs_$PID.txt"

try {
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $slf4jSrcs = Get-ChildItem -Path "windows\src\test\java\org\slf4j\*.java" | ForEach-Object { $_.FullName }
    $modelSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\model\*.java" | ForEach-Object { $_.FullName }
    $opSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\operation\*.java" | ForEach-Object { $_.FullName }
    $fsSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\filesystem\*.java" | ForEach-Object { $_.FullName }
    $secSrcs = @(
        (Resolve-Path "core\src\main\java\org\peerlink\core\security\ScannerProvider.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\security\SecurityVerdict.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\security\SecureKeyStore.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\security\KeyStorageException.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\security\InMemorySecureKeyStore.java").Path
    )
    $safetySrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\safety\*.java" | ForEach-Object { $_.FullName }
    $compatSrcs = @(
        (Resolve-Path "core\src\main\java\org\peerlink\core\compatibility\CompatibilityAnalyzer.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\compatibility\CompatibilityCategory.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\compatibility\CompatibilityIssue.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\compatibility\CompatibilityReport.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\compatibility\CompatibilityResult.java").Path
    )
    $androidSrcs = @(
        (Resolve-Path "core\src\main\java\org\peerlink\core\android\AndroidNodeState.java").Path
    )
    $protoStubSrcs = Get-ChildItem -Path "windows\src\test\java\com\google\protobuf\*.java", "windows\src\test\java\org\peerlink\protocol\v1\*.java" | ForEach-Object { $_.FullName }
    $eventSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\event\*.java" | ForEach-Object { $_.FullName }
    $idSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\identity\IdentityMetadataStore.java" | ForEach-Object { $_.FullName }
    $transferSrcs = @(
        (Resolve-Path "core\src\main\java\org\peerlink\core\transfer\TransferSessionJournal.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\transfer\TransferSessionRecord.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\transfer\SqliteTransferSessionJournal.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\transfer\StagingDirectoryManager.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\transfer\CorruptChunkException.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\transfer\HashMismatchException.java").Path
    )
    $storageSrcs = Get-ChildItem -Path "windows\src\main\java\org\peerlink\desktop\storage\*.java" | ForEach-Object { $_.FullName }
    $testSrcs = @(
        (Resolve-Path "windows\src\test\java\org\peerlink\core\transfer\PeerTransferEngine.java").Path,
        (Resolve-Path "windows\src\test\java\org\peerlink\core\transfer\FileManifestBuilder.java").Path,
        (Resolve-Path "windows\src\test\java\org\peerlink\core\safety\Phase20HardeningTestRunner.java").Path
    )

    $allSrcs = @($slf4jSrcs) + @($protoStubSrcs) + @($modelSrcs) + @($opSrcs) + @($eventSrcs) + @($idSrcs) + @($fsSrcs) + @($secSrcs) + @($safetySrcs) + @($compatSrcs) + @($androidSrcs) + @($transferSrcs) + @($storageSrcs) + @($testSrcs)

    Set-Content -Path $argFile -Value ($allSrcs -join "`n")

    Write-Host "Compiling Phase 20 sources with javac..." -ForegroundColor Yellow
    & javac -d $outDir "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running Phase 20 Cross-Platform Production Hardening Test Suite..." -ForegroundColor Yellow
    & java -cp $outDir org.peerlink.core.safety.Phase20HardeningTestRunner
    if ($LASTEXITCODE -ne 0) {
        throw "Test execution failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    Remove-Item -Force $argFile -ErrorAction SilentlyContinue
}
