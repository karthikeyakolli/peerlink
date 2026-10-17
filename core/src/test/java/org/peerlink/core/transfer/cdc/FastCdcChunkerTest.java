package org.peerlink.core.transfer.cdc;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.List;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("FastCDC Content-Defined Chunker Tests")
class FastCdcChunkerTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("Chunking is deterministic on identical byte sequences")
    void deterministicChunking() {
        FastCdcChunker chunker = new FastCdcChunker(16 * 1024, 64 * 1024, 128 * 1024);
        byte[] data = new byte[256 * 1024];
        new Random(42).nextBytes(data);

        List<ContentDefinedChunk> chunks1 = chunker.chunk(data);
        List<ContentDefinedChunk> chunks2 = chunker.chunk(data);

        assertEquals(chunks1.size(), chunks2.size());
        for (int i = 0; i < chunks1.size(); i++) {
            assertEquals(chunks1.get(i).chunkIndex(), chunks2.get(i).chunkIndex());
            assertEquals(chunks1.get(i).offsetBytes(), chunks2.get(i).offsetBytes());
            assertEquals(chunks1.get(i).lengthBytes(), chunks2.get(i).lengthBytes());
            assertEquals(chunks1.get(i).sha256Hex(), chunks2.get(i).sha256Hex());
        }
    }

    @Test
    @DisplayName("Chunk sizes respect min and max constraints (except final chunk at EOF)")
    void chunkSizesWithinBounds() {
        int min = 8 * 1024;
        int target = 16 * 1024;
        int max = 32 * 1024;
        FastCdcChunker chunker = new FastCdcChunker(min, target, max);

        byte[] data = new byte[500 * 1024];
        new Random(1234).nextBytes(data);

        List<ContentDefinedChunk> chunks = chunker.chunk(data);
        assertFalse(chunks.isEmpty());

        long accumulatedOffset = 0;
        for (int i = 0; i < chunks.size(); i++) {
            ContentDefinedChunk chunk = chunks.get(i);
            assertEquals(accumulatedOffset, chunk.offsetBytes());
            accumulatedOffset += chunk.lengthBytes();

            // All chunks except possibly the last one must be >= min
            if (i < chunks.size() - 1) {
                assertTrue(chunk.lengthBytes() >= min, 
                        "Chunk " + i + " size " + chunk.lengthBytes() + " < min " + min);
            }
            assertTrue(chunk.lengthBytes() <= max, 
                    "Chunk " + i + " size " + chunk.lengthBytes() + " > max " + max);
        }
        assertEquals(data.length, accumulatedOffset);
    }

    @Test
    @DisplayName("Insertion at index 0 preserves majority of downstream chunk hashes (Shift Resistance)")
    void insertionShiftResistance() {
        int min = 8 * 1024;
        int target = 16 * 1024;
        int max = 32 * 1024;
        FastCdcChunker chunker = new FastCdcChunker(min, target, max);

        byte[] base = new byte[512 * 1024];
        new Random(999).nextBytes(base);

        // Prepend 128 bytes to simulate insertion at the head
        byte[] inserted = new byte[base.length + 128];
        Arrays.fill(inserted, 0, 128, (byte) 0xAA);
        System.arraycopy(base, 0, inserted, 128, base.length);

        List<ContentDefinedChunk> baseChunks = chunker.chunk(base);
        List<ContentDefinedChunk> modifiedChunks = chunker.chunk(inserted);

        // Extract SHA-256 sets
        var baseHashes = baseChunks.stream().map(ContentDefinedChunk::sha256Hex).toList();
        var modifiedHashes = modifiedChunks.stream().map(ContentDefinedChunk::sha256Hex).toList();

        long matchingCount = modifiedHashes.stream().filter(baseHashes::contains).count();
        double reuseRatio = (double) matchingCount / baseChunks.size();

        // FastCDC should preserve > 80% of chunks despite head insertion!
        // (Whereas fixed-size chunking would have a 0% reuse ratio!)
        assertTrue(reuseRatio >= 0.70, 
                "Expected >= 70% chunk reuse after insertion, got: " + (reuseRatio * 100) + "%");
    }

    @Test
    @DisplayName("Empty and small files are handled safely")
    void emptyAndSmallFiles() throws IOException {
        FastCdcChunker chunker = new FastCdcChunker(16 * 1024, 64 * 1024, 128 * 1024);

        // Empty file
        Path emptyFile = tempDir.resolve("empty.dat");
        Files.write(emptyFile, new byte[0]);
        List<ContentDefinedChunk> emptyChunks = chunker.chunk(emptyFile);
        assertTrue(emptyChunks.isEmpty());

        // Small file (smaller than min chunk size)
        Path smallFile = tempDir.resolve("small.dat");
        byte[] smallData = "Hello PeerLink FastCDC".getBytes();
        Files.write(smallFile, smallData);
        List<ContentDefinedChunk> smallChunks = chunker.chunk(smallFile);
        assertEquals(1, smallChunks.size());
        assertEquals(smallData.length, smallChunks.get(0).lengthBytes());
        assertEquals(0, smallChunks.get(0).offsetBytes());
    }
}
