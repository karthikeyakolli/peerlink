package org.peerlink.core.transfer.compression;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.peerlink.core.transfer.FileManifestBuilder;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Adaptive Compression Pipeline Tests")
class AdaptiveCompressionPipelineTest {

    @Test
    @DisplayName("Entropy detector identifies text, code, and logs as compressible (< 7.5 bits/byte)")
    void identifiesCompressibleContent() {
        byte[] textData = "{\"users\": [{\"id\": 1, \"name\": \"Alice\", \"role\": \"admin\"}]}".repeat(100).getBytes(StandardCharsets.UTF_8);
        double entropy = EntropyDetector.calculateShannonEntropy(textData);

        assertTrue(entropy < 6.0, "Text data entropy should be low: " + entropy);
        assertTrue(EntropyDetector.isCompressible(textData), "Text data must be deemed compressible");
    }

    @Test
    @DisplayName("Entropy detector identifies high-entropy data (random or already compressed) and skips compression")
    void identifiesPreCompressedData() {
        byte[] randomData = new byte[8 * 1024];
        new Random(42).nextBytes(randomData);
        double entropy = EntropyDetector.calculateShannonEntropy(randomData);

        assertTrue(entropy > 7.7, "Random data entropy should be high: " + entropy);
        assertFalse(EntropyDetector.isCompressible(randomData), "Pre-compressed data must not be compressed");
    }

    @Test
    @DisplayName("Compresses repetitive text payload with > 70% compression ratio and roundtrips identically")
    void compressesAndDecompressesRoundtrip() throws Exception {
        AdaptiveCompressionPipeline pipeline = new AdaptiveCompressionPipeline();

        byte[] original = "PeerLink P2P Zero-Trust Fast Transfer Sync Protocol. ".repeat(500).getBytes(StandardCharsets.UTF_8);
        String originalSha = FileManifestBuilder.calculateSha256Hex(original);

        CompressedBlock block = pipeline.compress(original);

        assertTrue(block.isCompressed(), "Repetitive data must be compressed");
        double ratio = (double) block.payload().length / original.length;
        assertTrue(ratio < 0.30, "Expected >70% compression ratio, got: " + (ratio * 100) + "%");

        byte[] decompressed = pipeline.decompress(block.payload(), originalSha);

        assertArrayEquals(original, decompressed);
        assertEquals(originalSha, FileManifestBuilder.calculateSha256Hex(decompressed));
    }

    @Test
    @DisplayName("High entropy data passes through uncompressed without overhead")
    void highEntropyPassesThrough() throws Exception {
        AdaptiveCompressionPipeline pipeline = new AdaptiveCompressionPipeline();

        byte[] randomBytes = new byte[4 * 1024];
        new Random(99).nextBytes(randomBytes);
        String sha = FileManifestBuilder.calculateSha256Hex(randomBytes);

        CompressedBlock block = pipeline.compress(randomBytes);

        assertFalse(block.isCompressed(), "High entropy data should pass through uncompressed");
        byte[] restored = pipeline.decompress(block.payload(), sha);

        assertArrayEquals(randomBytes, restored);
    }

    @Test
    @DisplayName("Decompression fails and rejects corrupted compressed stream")
    void rejectsCorruptedCompressedStream() {
        AdaptiveCompressionPipeline pipeline = new AdaptiveCompressionPipeline();

        byte[] original = "Important secure backup data ".repeat(100).getBytes(StandardCharsets.UTF_8);
        CompressedBlock block = pipeline.compress(original);
        assertTrue(block.isCompressed());

        byte[] corrupted = block.payload().clone();
        corrupted[10] = (byte) (corrupted[10] ^ 0xFF); // Corrupt byte

        assertThrows(SecurityException.class, () -> {
            pipeline.decompress(corrupted, "dummyExpectedSha");
        });
    }
}
