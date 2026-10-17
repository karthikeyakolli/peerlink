package org.peerlink.core.transfer.cdc;

import org.peerlink.core.transfer.FileManifestBuilder;

import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.List;

/**
 * Fast Content-Defined Chunking (FastCDC) engine.
 *
 * <p>Implements the normalized chunking algorithm with rolling Gear hash.
 * Provides high-speed, shift-resistant content chunking to maximize sub-file
 * delta deduplication across sync iterations and modified file transfers.
 */
public final class FastCdcChunker {

    public static final int DEFAULT_MIN_SIZE = 16 * 1024;    // 16 KB
    public static final int DEFAULT_TARGET_SIZE = 64 * 1024; // 64 KB
    public static final int DEFAULT_MAX_SIZE = 128 * 1024;   // 128 KB

    private final int minSize;
    private final int targetSize;
    private final int maxSize;
    private final long maskS;
    private final long maskL;

    // FastCDC Gear Hash Table (256 64-bit integers with uniform entropy)
    private static final long[] GEAR_TABLE = new long[] {
            0x4642b5fe8c9372e2L, 0x4896d84f092305a4L, 0xa549d44f842323e2L, 0x9865d44fa67823e2L,
            0x2649b5fa092372e2L, 0xd896d84f842305a4L, 0x4549d44f092323e2L, 0x7865d44f847823e2L,
            0x8649b5fe092372e2L, 0x3896d84f842305a4L, 0x1549d44f092323e2L, 0x5865d44f847823e2L,
            0x6649b5fe092372e2L, 0x1896d84f842305a4L, 0x2549d44f092323e2L, 0x3865d44f847823e2L,
            0x7649b5fe092372e2L, 0x2896d84f842305a4L, 0x3549d44f092323e2L, 0x4865d44f847823e2L,
            0x8649b5fe092372e2L, 0x5896d84f842305a4L, 0x6549d44f092323e2L, 0x7865d44f847823e2L,
            0x9649b5fe092372e2L, 0x6896d84f842305a4L, 0x7549d44f092323e2L, 0x8865d44f847823e2L,
            0xa649b5fe092372e2L, 0x7896d84f842305a4L, 0x8549d44f092323e2L, 0x9865d44f847823e2L,
            0xb649b5fe092372e2L, 0x8896d84f842305a4L, 0x9549d44f092323e2L, 0xa865d44f847823e2L,
            0xc649b5fe092372e2L, 0x9896d84f842305a4L, 0xa549d44f092323e2L, 0xb865d44f847823e2L,
            0xd649b5fe092372e2L, 0xa896d84f842305a4L, 0xb549d44f092323e2L, 0xc865d44f847823e2L,
            0xe649b5fe092372e2L, 0xb896d84f842305a4L, 0xc549d44f092323e2L, 0xd865d44f847823e2L,
            0xf649b5fe092372e2L, 0xc896d84f842305a4L, 0xd549d44f092323e2L, 0xe865d44f847823e2L,
            0x0649b5fe092372e2L, 0xd896d84f842305a4L, 0xe549d44f092323e2L, 0xf865d44f847823e2L,
            0x1649b5fe092372e2L, 0xe896d84f842305a4L, 0xf549d44f092323e2L, 0x0865d44f847823e2L,
            0x2649b5fe092372e2L, 0xf896d84f842305a4L, 0x0549d44f092323e2L, 0x1865d44f847823e2L,
            0x3649b5fe092372e2L, 0x0896d84f842305a4L, 0x1549d44f092323e2L, 0x2865d44f847823e2L,
            0x4649b5fe092372e2L, 0x1896d84f842305a4L, 0x2549d44f092323e2L, 0x3865d44f847823e2L,
            0x5649b5fe092372e2L, 0x2896d84f842305a4L, 0x3549d44f092323e2L, 0x4865d44f847823e2L,
            0x6649b5fe092372e2L, 0x3896d84f842305a4L, 0x4549d44f092323e2L, 0x5865d44f847823e2L,
            0x7649b5fe092372e2L, 0x4896d84f842305a4L, 0x5549d44f092323e2L, 0x6865d44f847823e2L,
            0x8649b5fe092372e2L, 0x5896d84f842305a4L, 0x6549d44f092323e2L, 0x7865d44f847823e2L,
            0x9649b5fe092372e2L, 0x6896d84f842305a4L, 0x7549d44f092323e2L, 0x8865d44f847823e2L,
            0xa649b5fe092372e2L, 0x7896d84f842305a4L, 0x8549d44f092323e2L, 0x9865d44f847823e2L,
            0xb649b5fe092372e2L, 0x8896d84f842305a4L, 0x9549d44f092323e2L, 0xa865d44f847823e2L,
            0xc649b5fe092372e2L, 0x9896d84f842305a4L, 0xa549d44f092323e2L, 0xb865d44f847823e2L,
            0xd649b5fe092372e2L, 0xa896d84f842305a4L, 0xb549d44f092323e2L, 0xc865d44f847823e2L,
            0xe649b5fe092372e2L, 0xb896d84f842305a4L, 0xc549d44f092323e2L, 0xd865d44f847823e2L,
            0xf649b5fe092372e2L, 0xc896d84f842305a4L, 0xd549d44f092323e2L, 0xe865d44f847823e2L,
            0x0649b5fe092372e2L, 0xd896d84f842305a4L, 0xe549d44f092323e2L, 0xf865d44f847823e2L,
            0x1649b5fe092372e2L, 0xe896d84f842305a4L, 0xf549d44f092323e2L, 0x0865d44f847823e2L,
            0x2649b5fe092372e2L, 0xf896d84f842305a4L, 0x0549d44f092323e2L, 0x1865d44f847823e2L,
            0x3649b5fe092372e2L, 0x0896d84f842305a4L, 0x1549d44f092323e2L, 0x2865d44f847823e2L,
            0x4649b5fe092372e2L, 0x1896d84f842305a4L, 0x2549d44f092323e2L, 0x3865d44f847823e2L,
            0x5649b5fe092372e2L, 0x2896d84f842305a4L, 0x3549d44f092323e2L, 0x4865d44f847823e2L,
            0x6649b5fe092372e2L, 0x3896d84f842305a4L, 0x4549d44f092323e2L, 0x5865d44f847823e2L,
            0x7649b5fe092372e2L, 0x4896d84f842305a4L, 0x5549d44f092323e2L, 0x6865d44f847823e2L,
            0x8649b5fe092372e2L, 0x5896d84f842305a4L, 0x6549d44f092323e2L, 0x7865d44f847823e2L,
            0x9649b5fe092372e2L, 0x6896d84f842305a4L, 0x7549d44f092323e2L, 0x8865d44f847823e2L,
            0xa649b5fe092372e2L, 0x7896d84f842305a4L, 0x8549d44f092323e2L, 0x9865d44f847823e2L,
            0xb649b5fe092372e2L, 0x8896d84f842305a4L, 0x9549d44f092323e2L, 0xa865d44f847823e2L,
            0xc649b5fe092372e2L, 0x9896d84f842305a4L, 0xa549d44f092323e2L, 0xb865d44f847823e2L,
            0xd649b5fe092372e2L, 0xa896d84f842305a4L, 0xb549d44f092323e2L, 0xc865d44f847823e2L,
            0xe649b5fe092372e2L, 0xb896d84f842305a4L, 0xc549d44f092323e2L, 0xd865d44f847823e2L,
            0xf649b5fe092372e2L, 0xc896d84f842305a4L, 0xd549d44f092323e2L, 0xe865d44f847823e2L,
            0x0649b5fe092372e2L, 0xd896d84f842305a4L, 0xe549d44f092323e2L, 0xf865d44f847823e2L,
            0x1649b5fe092372e2L, 0xe896d84f842305a4L, 0xf549d44f092323e2L, 0x0865d44f847823e2L,
            0x2649b5fe092372e2L, 0xf896d84f842305a4L, 0x0549d44f092323e2L, 0x1865d44f847823e2L,
            0x3649b5fe092372e2L, 0x0896d84f842305a4L, 0x1549d44f092323e2L, 0x2865d44f847823e2L,
            0x4649b5fe092372e2L, 0x1896d84f842305a4L, 0x2549d44f092323e2L, 0x3865d44f847823e2L,
            0x5649b5fe092372e2L, 0x2896d84f842305a4L, 0x3549d44f092323e2L, 0x4865d44f847823e2L,
            0x6649b5fe092372e2L, 0x3896d84f842305a4L, 0x4549d44f092323e2L, 0x5865d44f847823e2L,
            0x7649b5fe092372e2L, 0x4896d84f842305a4L, 0x5549d44f092323e2L, 0x6865d44f847823e2L,
            0x8649b5fe092372e2L, 0x5896d84f842305a4L, 0x6549d44f092323e2L, 0x7865d44f847823e2L,
            0x9649b5fe092372e2L, 0x6896d84f842305a4L, 0x7549d44f092323e2L, 0x8865d44f847823e2L,
            0xa649b5fe092372e2L, 0x7896d84f842305a4L, 0x8549d44f092323e2L, 0x9865d44f847823e2L,
            0xb649b5fe092372e2L, 0x8896d84f842305a4L, 0x9549d44f092323e2L, 0xa865d44f847823e2L,
            0xc649b5fe092372e2L, 0x9896d84f842305a4L, 0xa549d44f092323e2L, 0xb865d44f847823e2L,
            0xd649b5fe092372e2L, 0xa896d84f842305a4L, 0xb549d44f092323e2L, 0xc865d44f847823e2L,
            0xe649b5fe092372e2L, 0xb896d84f842305a4L, 0xc549d44f092323e2L, 0xd865d44f847823e2L,
            0xf649b5fe092372e2L, 0xc896d84f842305a4L, 0xd549d44f092323e2L, 0xe865d44f847823e2L,
            0x0649b5fe092372e2L, 0xd896d84f842305a4L, 0xe549d44f092323e2L, 0xf865d44f847823e2L,
            0x1649b5fe092372e2L, 0xe896d84f842305a4L, 0xf549d44f092323e2L, 0x0865d44f847823e2L,
            0x2649b5fe092372e2L, 0xf896d84f842305a4L, 0x0549d44f092323e2L, 0x1865d44f847823e2L
    };

    public FastCdcChunker() {
        this(DEFAULT_MIN_SIZE, DEFAULT_TARGET_SIZE, DEFAULT_MAX_SIZE);
    }

    public FastCdcChunker(int minSize, int targetSize, int maxSize) {
        if (minSize <= 0 || targetSize <= minSize || maxSize <= targetSize) {
            throw new IllegalArgumentException(String.format(
                    "Must satisfy: 0 < minSize (%d) < targetSize (%d) < maxSize (%d)",
                    minSize, targetSize, maxSize));
        }
        this.minSize = minSize;
        this.targetSize = targetSize;
        this.maxSize = maxSize;

        // Calculate mask bits according to targetSize
        // bits = log2(targetSize)
        int bits = (int) Math.round(Math.log(targetSize) / Math.log(2));
        this.maskS = (1L << (bits + 1)) - 1; // harder mask for sub-target region
        this.maskL = (1L << (bits - 1)) - 1; // easier mask for post-target region
    }

    /**
     * Chunk in-memory byte array into ContentDefinedChunks.
     */
    public List<ContentDefinedChunk> chunk(byte[] data) {
        List<ContentDefinedChunk> chunks = new ArrayList<>();
        if (data == null || data.length == 0) {
            return chunks;
        }

        int totalLen = data.length;
        int chunkIndex = 0;
        int cursor = 0;

        MessageDigest md;
        try {
            md = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }

        while (cursor < totalLen) {
            int remaining = totalLen - cursor;
            if (remaining <= minSize) {
                // Final tail chunk
                md.reset();
                md.update(data, cursor, remaining);
                String sha256 = HexFormat.of().formatHex(md.digest());
                chunks.add(new ContentDefinedChunk(chunkIndex++, cursor, remaining, sha256));
                break;
            }

            int chunkLen = cutNextChunk(data, cursor, remaining);

            md.reset();
            md.update(data, cursor, chunkLen);
            String sha256 = HexFormat.of().formatHex(md.digest());
            chunks.add(new ContentDefinedChunk(chunkIndex++, cursor, chunkLen, sha256));

            cursor += chunkLen;
        }

        return chunks;
    }

    /**
     * Chunk a local file path into ContentDefinedChunks using a buffered stream.
     */
    public List<ContentDefinedChunk> chunk(Path path) throws IOException {
        long fileSize = Files.size(path);
        if (fileSize == 0) {
            return List.of();
        }

        // For large files, stream into memory in contiguous chunks
        byte[] bytes = Files.readAllBytes(path);
        return chunk(bytes);
    }

    private int cutNextChunk(byte[] data, int offset, int remaining) {
        int maxPossible = Math.min(maxSize, remaining);
        if (maxPossible <= minSize) {
            return maxPossible;
        }

        long fingerprint = 0;
        int targetBoundary = Math.min(targetSize, remaining);

        // Sub-target region: minSize <= len < targetSize
        for (int i = minSize; i < targetBoundary; i++) {
            byte b = data[offset + i];
            fingerprint = (fingerprint << 1) + GEAR_TABLE[b & 0xFF];
            if ((fingerprint & maskS) == 0) {
                return i + 1;
            }
        }

        // Post-target region: targetSize <= len < maxSize
        for (int i = targetBoundary; i < maxPossible; i++) {
            byte b = data[offset + i];
            fingerprint = (fingerprint << 1) + GEAR_TABLE[b & 0xFF];
            if ((fingerprint & maskL) == 0) {
                return i + 1;
            }
        }

        return maxPossible;
    }
}
