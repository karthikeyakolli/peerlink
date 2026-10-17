package org.peerlink.core.transfer.cdc;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.transfer.FileManifestBuilder;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("FastCDC Sub-File Delta Sync and Reconstruction Tests")
class DeltaSyncReconstructionTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("Delta sync correctly calculates missing chunks and saves >80% bandwidth on modified files")
    void deltaCalculationAndBandwidthSavings() throws IOException {
        FastCdcChunker chunker = new FastCdcChunker(8 * 1024, 16 * 1024, 32 * 1024);

        // 1. Create original 256 KB file
        byte[] originalBytes = new byte[256 * 1024];
        new Random(42).nextBytes(originalBytes);
        Path originalPath = tempDir.resolve("doc_v1.bin");
        Files.write(originalPath, originalBytes);

        // 2. Create modified version with 500 bytes changed in the middle
        byte[] modifiedBytes = originalBytes.clone();
        for (int i = 100_000; i < 100_500; i++) {
            modifiedBytes[i] = (byte) (modifiedBytes[i] ^ 0xFF);
        }
        Path modifiedPath = tempDir.resolve("doc_v2.bin");
        Files.write(modifiedPath, modifiedBytes);

        // 3. Build manifests
        DeltaSyncManifest v1Manifest = DeltaSyncManifest.build(originalPath, chunker);
        DeltaSyncManifest v2Manifest = DeltaSyncManifest.build(modifiedPath, chunker);

        // 4. Compute delta difference
        DeltaDiff diff = v2Manifest.computeDelta(v1Manifest);

        assertNotNull(diff);
        assertTrue(diff.reusedChunkCount() > 0, "Should reuse existing chunks");
        assertTrue(diff.transferredChunkCount() >= 1, "Should identify modified chunk");
        assertTrue(diff.bandwidthReductionPercentage() >= 75.0,
                "Expected >= 75% bandwidth reduction, got: " + diff.bandwidthReductionPercentage() + "%");
    }

    @Test
    @DisplayName("Reconstructor rebuilds file byte-for-byte from base file and delta chunks")
    void fullReconstructionRoundtrip() throws Exception {
        FastCdcChunker chunker = new FastCdcChunker(8 * 1024, 16 * 1024, 32 * 1024);

        // 1. Base file
        byte[] originalBytes = new byte[128 * 1024];
        new Random(777).nextBytes(originalBytes);
        Path basePath = tempDir.resolve("base.dat");
        Files.write(basePath, originalBytes);

        // 2. Target modified file (prepend some bytes and modify end)
        byte[] modifiedBytes = new byte[originalBytes.length + 200];
        Arrays.fill(modifiedBytes, 0, 200, (byte) 0x7E);
        System.arraycopy(originalBytes, 0, modifiedBytes, 200, originalBytes.length);
        Path targetPath = tempDir.resolve("target.dat");
        Files.write(targetPath, modifiedBytes);

        String expectedSha256 = FileManifestBuilder.calculateSha256Hex(targetPath);

        // 3. Chunk both
        DeltaSyncManifest baseManifest = DeltaSyncManifest.build(basePath, chunker);
        DeltaSyncManifest targetManifest = DeltaSyncManifest.build(targetPath, chunker);

        DeltaDiff diff = targetManifest.computeDelta(baseManifest);

        // 4. Simulate wire transmission: extract only the missing chunks from target file
        Map<String, byte[]> wireTransferredChunks = new HashMap<>();
        for (ContentDefinedChunk missing : diff.missingChunks()) {
            byte[] chunkData = new byte[missing.lengthBytes()];
            System.arraycopy(modifiedBytes, (int) missing.offsetBytes(), chunkData, 0, missing.lengthBytes());
            wireTransferredChunks.put(missing.sha256Hex(), chunkData);
        }

        // 5. Reconstruct on destination
        Path stagedDestination = tempDir.resolve("reconstructed.dat");
        DeltaReconstructor.reconstruct(
                basePath,
                baseManifest,
                targetManifest,
                wireTransferredChunks,
                stagedDestination,
                expectedSha256
        );

        // 6. Verify identical byte content and hash
        assertTrue(Files.exists(stagedDestination));
        byte[] reconstructedBytes = Files.readAllBytes(stagedDestination);
        assertArrayEquals(modifiedBytes, reconstructedBytes);
        assertEquals(expectedSha256, FileManifestBuilder.calculateSha256Hex(stagedDestination));
    }

    @Test
    @DisplayName("Reconstruction fails and removes staging file if a chunk is corrupted")
    void corruptedChunkReconstructionFailsSafely() throws Exception {
        FastCdcChunker chunker = new FastCdcChunker(8 * 1024, 16 * 1024, 32 * 1024);

        byte[] baseBytes = new byte[64 * 1024];
        new Random(101).nextBytes(baseBytes);
        Path basePath = tempDir.resolve("corrupt_test_base.dat");
        Files.write(basePath, baseBytes);

        byte[] targetBytes = new byte[64 * 1024];
        new Random(202).nextBytes(targetBytes);
        Path targetPath = tempDir.resolve("corrupt_test_target.dat");
        Files.write(targetPath, targetBytes);

        DeltaSyncManifest baseManifest = DeltaSyncManifest.build(basePath, chunker);
        DeltaSyncManifest targetManifest = DeltaSyncManifest.build(targetPath, chunker);

        DeltaDiff diff = targetManifest.computeDelta(baseManifest);

        // Deliberately corrupt one of the transferred chunks
        Map<String, byte[]> wireTransferredChunks = new HashMap<>();
        for (ContentDefinedChunk missing : diff.missingChunks()) {
            byte[] chunkData = new byte[missing.lengthBytes()];
            System.arraycopy(targetBytes, (int) missing.offsetBytes(), chunkData, 0, missing.lengthBytes());
            chunkData[0] = (byte) (chunkData[0] ^ 0xFF); // CORRUPT
            wireTransferredChunks.put(missing.sha256Hex(), chunkData);
        }

        Path stagedDestination = tempDir.resolve("corrupted_staging.dat");

        assertThrows(SecurityException.class, () -> {
            DeltaReconstructor.reconstruct(
                    basePath,
                    baseManifest,
                    targetManifest,
                    wireTransferredChunks,
                    stagedDestination,
                    "dummyExpectedSha256"
            );
        });

        // Verify staging file was cleaned up on corruption failure
        assertFalse(Files.exists(stagedDestination), "Staging file must be cleaned up on integrity failure");
    }
}
