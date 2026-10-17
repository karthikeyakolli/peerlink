$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent
Set-Location $RepoRoot

$outDir = Join-Path $env:TEMP "phase19_test_out_$PID"
$argFile = Join-Path $env:TEMP "phase19_srcs_$PID.txt"

try {
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $slf4jSrcs = Get-ChildItem -Path "windows\src\test\java\org\slf4j\*.java" | ForEach-Object { $_.FullName }
    $protoStubSrcs = Get-ChildItem -Path "windows\src\test\java\com\google\protobuf\*.java", "windows\src\test\java\org\peerlink\protocol\v1\*.java" | ForEach-Object { $_.FullName }
    $opSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\operation\*.java" | ForEach-Object { $_.FullName }
    $eventSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\event\*.java" | ForEach-Object { $_.FullName }
    $idSrcs = Get-ChildItem -Path "core\src\main\java\org\peerlink\core\identity\IdentityMetadataStore.java" | ForEach-Object { $_.FullName }
    $tfSrcs = @(
        (Resolve-Path "core\src\main\java\org\peerlink\core\transfer\TransferSessionJournal.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\transfer\TransferSessionRecord.java").Path,
        (Resolve-Path "core\src\main\java\org\peerlink\core\transfer\SqliteTransferSessionJournal.java").Path
    )
    $storageSrcs = Get-ChildItem -Path "windows\src\main\java\org\peerlink\desktop\storage\*.java" | ForEach-Object { $_.FullName }
    $testSrcs = @(
        (Resolve-Path "windows\src\test\java\org\peerlink\core\transfer\PeerTransferEngine.java").Path,
        (Resolve-Path "windows\src\test\java\org\peerlink\desktop\storage\Phase19StandaloneTestRunner.java").Path
    )

    $allSrcs = @($slf4jSrcs) + @($protoStubSrcs) + @($opSrcs) + @($eventSrcs) + @($idSrcs) + @($tfSrcs) + @($storageSrcs) + @($testSrcs)

    Set-Content -Path $argFile -Value ($allSrcs -join "`n")

    Write-Host "Compiling Phase 19 sources with javac..." -ForegroundColor Yellow
    & javac -d $outDir "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running Phase 19 Standalone Test Suite..." -ForegroundColor Yellow
    & java -cp $outDir org.peerlink.desktop.storage.Phase19StandaloneTestRunner
    if ($LASTEXITCODE -ne 0) {
        throw "Test execution failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    Remove-Item -Force $argFile -ErrorAction SilentlyContinue
}
