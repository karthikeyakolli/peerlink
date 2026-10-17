package org.peerlink.core.transfer.compression;

import org.peerlink.core.transfer.FileManifestBuilder;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.zip.DataFormatException;
import java.util.zip.Deflater;
import java.util.zip.Inflater;

/**
 * Adaptive Block Compression Pipeline.
 *
 * <p>Integrates Shannon entropy screening with high-speed block compression.
 * Bypasses high-entropy data (images, videos, encrypted chunks) and compresses
 * text, source code, documents, and disk snapshots, verifying SHA-256 integrity
 * upon decompression before staging.
 */
public final class AdaptiveCompressionPipeline {

    private static final byte MAGIC_RAW = 0x00;
    private static final byte MAGIC_DEFLATE = 0x01;
    private static final int HEADER_SIZE = 5; // 1 byte magic + 4 bytes original length

    private final int compressionLevel;

    public AdaptiveCompressionPipeline() {
        this(Deflater.DEFAULT_COMPRESSION);
    }

    public AdaptiveCompressionPipeline(int compressionLevel) {
        this.compressionLevel = compressionLevel;
    }

    /**
     * Compress a block of data adaptively.
     */
    public CompressedBlock compress(byte[] data) {
        if (data == null || data.length == 0) {
            byte[] emptyPayload = new byte[HEADER_SIZE];
            emptyPayload[0] = MAGIC_RAW;
            return new CompressedBlock(emptyPayload, false, 0, HEADER_SIZE);
        }

        int origLen = data.length;

        // Skip compression for tiny chunks or high-entropy blocks
        if (origLen < 128 || !EntropyDetector.isCompressible(data)) {
            byte[] rawPayload = new byte[HEADER_SIZE + origLen];
            rawPayload[0] = MAGIC_RAW;
            ByteBuffer.wrap(rawPayload, 1, 4).putInt(origLen);
            System.arraycopy(data, 0, rawPayload, HEADER_SIZE, origLen);
            return new CompressedBlock(rawPayload, false, origLen, rawPayload.length);
        }

        // Compress using Deflater
        Deflater deflater = new Deflater(compressionLevel);
        deflater.setInput(data);
        deflater.finish();

        ByteArrayOutputStream baos = new ByteArrayOutputStream(origLen);
        byte[] buffer = new byte[8192];
        while (!deflater.finished()) {
            int count = deflater.deflate(buffer);
            baos.write(buffer, 0, count);
        }
        deflater.end();

        byte[] compressedData = baos.toByteArray();

        // If compression didn't actually reduce size, pass through as RAW
        if (compressedData.length + HEADER_SIZE >= origLen) {
            byte[] rawPayload = new byte[HEADER_SIZE + origLen];
            rawPayload[0] = MAGIC_RAW;
            ByteBuffer.wrap(rawPayload, 1, 4).putInt(origLen);
            System.arraycopy(data, 0, rawPayload, HEADER_SIZE, origLen);
            return new CompressedBlock(rawPayload, false, origLen, rawPayload.length);
        }

        byte[] finalPayload = new byte[HEADER_SIZE + compressedData.length];
        finalPayload[0] = MAGIC_DEFLATE;
        ByteBuffer.wrap(finalPayload, 1, 4).putInt(origLen);
        System.arraycopy(compressedData, 0, finalPayload, HEADER_SIZE, compressedData.length);

        return new CompressedBlock(finalPayload, true, origLen, finalPayload.length);
    }

    /**
     * Decompress a wire payload and verify its cryptographic hash.
     *
     * @param payload Wire payload with 5-byte header
     * @param expectedSha256 Expected SHA-256 hex string of uncompressed bytes
     * @return original uncompressed byte array
     * @throws SecurityException if decompressed data fails hash verification or format is corrupted
     */
    public byte[] decompress(byte[] payload, String expectedSha256) throws SecurityException {
        if (payload == null || payload.length < HEADER_SIZE) {
            throw new SecurityException("Payload too short for compression header");
        }

        byte magic = payload[0];
        int originalLength = ByteBuffer.wrap(payload, 1, 4).getInt();

        if (originalLength < 0 || originalLength > 100_000_000) { // Safety ceiling: 100 MB max per block
            throw new SecurityException("Illegal uncompressed length: " + originalLength);
        }

        byte[] decompressedBytes;

        if (magic == MAGIC_RAW) {
            decompressedBytes = new byte[originalLength];
            System.arraycopy(payload, HEADER_SIZE, decompressedBytes, 0, originalLength);
        } else if (magic == MAGIC_DEFLATE) {
            Inflater inflater = new Inflater();
            inflater.setInput(payload, HEADER_SIZE, payload.length - HEADER_SIZE);

            decompressedBytes = new byte[originalLength];
            try {
                int resultLength = inflater.inflate(decompressedBytes);
                if (resultLength != originalLength || !inflater.finished()) {
                    throw new SecurityException("Corrupted compressed block: size mismatch");
                }
            } catch (DataFormatException e) {
                throw new SecurityException("Failed to decompress corrupted block stream", e);
            } finally {
                inflater.end();
            }
        } else {
            throw new SecurityException("Unknown compression magic byte: " + magic);
        }

        // Integrity verification
        if (expectedSha256 != null && !expectedSha256.isBlank()) {
            String actualSha = FileManifestBuilder.calculateSha256Hex(decompressedBytes);
            if (!actualSha.equalsIgnoreCase(expectedSha256)) {
                throw new SecurityException(String.format(
                        "Decompressed block hash mismatch: expected %s, got %s",
                        expectedSha256, actualSha));
            }
        }

        return decompressedBytes;
    }
}
