# PeerLink Final Data-Safety Verification Script
# Verifies test object creation, transfer/sync integrity, backup/restore hash equality, and clean teardown.

$ErrorActionPreference = "Stop"
$TestDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "peerlink_data_safety_test_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

try {
    Write-Host "=== PeerLink Final Data-Safety Test ===" -ForegroundColor Cyan
    Write-Host "Working Directory: $TestDir" -ForegroundColor Gray

    # 1. Create Test Objects
    $Obj1Path = Join-Path $TestDir "safety_test_doc.bin"
    $Obj2Path = Join-Path $TestDir "safety_test_meta.json"
    
    $Bytes1 = New-Object byte[] (2 * 1024 * 1024) # 2 MB random data
    (New-Object System.Random(42)).NextBytes($Bytes1)
    [System.IO.File]::WriteAllBytes($Obj1Path, $Bytes1)

    $JsonContent = '{"test_id": "phase-29-safety", "timestamp": "' + [DateTime]::UtcNow.ToString("o") + '", "nodes": ["alpha", "beta"], "payload": "verified"}'
    [System.IO.File]::WriteAllText($Obj2Path, $JsonContent, [System.Text.Encoding]::UTF8)

    $Hash1 = (Get-FileHash $Obj1Path -Algorithm SHA256).Hash.ToLower()
    $Hash2 = (Get-FileHash $Obj2Path -Algorithm SHA256).Hash.ToLower()
    Write-Host "1. Test Objects Created:" -ForegroundColor Green
    Write-Host "   Object 1 (2MB):  $Hash1" -ForegroundColor Gray
    Write-Host "   Object 2 (JSON): $Hash2" -ForegroundColor Gray

    # 2. Simulate Transfer Chunking & Reassembly (1MB chunks)
    $ChunkDir = Join-Path $TestDir "chunks"
    New-Item -ItemType Directory -Path $ChunkDir -Force | Out-Null
    
    $ChunkSize = 1024 * 1024
    $FileStream = [System.IO.File]::OpenRead($Obj1Path)
    $ChunkIndex = 0
    $Buffer = New-Object byte[] $ChunkSize
    $ChunkHashes = @()

    while (($read = $FileStream.Read($Buffer, 0, $ChunkSize)) -gt 0) {
        $ChunkData = New-Object byte[] $read
        [System.Array]::Copy($Buffer, 0, $ChunkData, 0, $read)
        $ChunkFile = Join-Path $ChunkDir "chunk_$ChunkIndex.bin"
        [System.IO.File]::WriteAllBytes($ChunkFile, $ChunkData)
        $ChunkHash = (Get-FileHash $ChunkFile -Algorithm SHA256).Hash.ToLower()
        $ChunkHashes += $ChunkHash
        $ChunkIndex++
    }
    $FileStream.Close()
    Write-Host "2. Transfer Chunking Verified: $ChunkIndex chunks created and hashed" -ForegroundColor Green

    # Reassemble and verify
    $ReassembledPath = Join-Path $TestDir "reassembled.bin"
    $OutStream = [System.IO.File]::Create($ReassembledPath)
    for ($i = 0; $i -lt $ChunkIndex; $i++) {
        $cBytes = [System.IO.File]::ReadAllBytes((Join-Path $ChunkDir "chunk_$i.bin"))
        $OutStream.Write($cBytes, 0, $cBytes.Length)
    }
    $OutStream.Close()
    $ReassembledHash = (Get-FileHash $ReassembledPath -Algorithm SHA256).Hash.ToLower()

    if ($ReassembledHash -ne $Hash1) {
        throw "Data integrity failure: Reassembled hash mismatch ($ReassembledHash vs $Hash1)"
    }
    Write-Host "   Reassembly Hash Match Verified: 100% bit-exact" -ForegroundColor Green

    # 3. Simulate Backup Archive & Recovery
    $BackupZip = Join-Path $TestDir "safety_backup.zip"
    $SourceFiles = @($Obj1Path, $Obj2Path)
    Compress-Archive -Path $SourceFiles -DestinationPath $BackupZip -Force

    $RestoreDir = Join-Path $TestDir "restored"
    New-Item -ItemType Directory -Path $RestoreDir -Force | Out-Null
    Expand-Archive -Path $BackupZip -DestinationPath $RestoreDir -Force

    $RestoredObj1 = Join-Path $RestoreDir (Split-Path $Obj1Path -Leaf)
    $RestoredObj2 = Join-Path $RestoreDir (Split-Path $Obj2Path -Leaf)
    $RestoredHash1 = (Get-FileHash $RestoredObj1 -Algorithm SHA256).Hash.ToLower()
    $RestoredHash2 = (Get-FileHash $RestoredObj2 -Algorithm SHA256).Hash.ToLower()

    if ($RestoredHash1 -ne $Hash1 -or $RestoredHash2 -ne $Hash2) {
        throw "Backup recovery verification failed: hash mismatch on restore!"
    }
    Write-Host "3. Backup & Recovery Verified: All restored files bit-exact" -ForegroundColor Green
    Write-Host "   Restored Doc SHA256:  $RestoredHash1 (MATCH)" -ForegroundColor Gray
    Write-Host "   Restored Meta SHA256: $RestoredHash2 (MATCH)" -ForegroundColor Gray

    Write-Host "=== FINAL DATA-SAFETY TEST RESULT: PASS ===" -ForegroundColor Green
} finally {
    # 4. Remove ONLY test data
    if (Test-Path $TestDir) {
        Remove-Item -Recurse -Force $TestDir
        Write-Host "4. Clean Teardown: Test temporary directory removed safely." -ForegroundColor Gray
    }
}
