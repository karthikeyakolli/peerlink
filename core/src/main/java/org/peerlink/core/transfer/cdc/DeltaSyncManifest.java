package org.peerlink.core.transfer.cdc;

import java.io.IOException;
import java.nio.file.Path;
import java.util.*;

/**
 * Manifest representing a file decomposed into content-defined chunks.
 * Enables computing missing chunks between revisions for bandwidth-minimized delta sync.
 */
public final class DeltaSyncManifest {

    private final List<ContentDefinedChunk> chunks;
    private final Map<String, ContentDefinedChunk> chunksBySha256;
    private final long totalBytes;

    public DeltaSyncManifest(List<ContentDefinedChunk> chunks) {
        this.chunks = List.copyOf(chunks);
        Map<String, ContentDefinedChunk> map = new HashMap<>();
        long total = 0;
        for (ContentDefinedChunk c : chunks) {
            map.putIfAbsent(c.sha256Hex(), c);
            total += c.lengthBytes();
        }
        this.chunksBySha256 = Collections.unmodifiableMap(map);
        this.totalBytes = total;
    }

    public static DeltaSyncManifest build(Path path, FastCdcChunker chunker) throws IOException {
        List<ContentDefinedChunk> chunks = chunker.chunk(path);
        return new DeltaSyncManifest(chunks);
    }

    public static DeltaSyncManifest build(byte[] data, FastCdcChunker chunker) {
        List<ContentDefinedChunk> chunks = chunker.chunk(data);
        return new DeltaSyncManifest(chunks);
    }

    public List<ContentDefinedChunk> chunks() {
        return chunks;
    }

    public long totalBytes() {
        return totalBytes;
    }

    public boolean containsChunk(String sha256Hex) {
        return chunksBySha256.containsKey(sha256Hex);
    }

    public ContentDefinedChunk getChunk(String sha256Hex) {
        return chunksBySha256.get(sha256Hex);
    }

    /**
     * Compute delta difference against a known local base manifest.
     *
     * @param baseManifest Manifest of the file version already present on the receiver
     * @return DeltaDiff detailing which chunks to transfer and bandwidth saved
     */
    public DeltaDiff computeDelta(DeltaSyncManifest baseManifest) {
        List<ContentDefinedChunk> missing = new ArrayList<>();
        int reusedCount = 0;
        long reusedBytes = 0;
        long transferredBytes = 0;

        for (ContentDefinedChunk chunk : chunks) {
            if (baseManifest != null && baseManifest.containsChunk(chunk.sha256Hex())) {
                reusedCount++;
                reusedBytes += chunk.lengthBytes();
            } else {
                missing.add(chunk);
                transferredBytes += chunk.lengthBytes();
            }
        }

        return new DeltaDiff(missing, reusedCount, reusedBytes, transferredBytes, totalBytes);
    }
}
