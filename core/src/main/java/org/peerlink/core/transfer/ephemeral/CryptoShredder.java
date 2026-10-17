package org.peerlink.core.transfer.ephemeral;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.Arrays;

/**
 * High-assurance cryptographic file shredder.
 * Overwrites physical file sectors using multi-pass cryptographically strong pseudo-random noise,
 * bitwise complements, and zeros before truncating and unlinking from the filesystem.
 */
public final class CryptoShredder {
    private static final Logger log = LoggerFactory.getLogger(CryptoShredder.class);
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final int BUFFER_SIZE = 64 * 1024; // 64 KB wipe chunk

    private CryptoShredder() {}

    /**
     * Securely shreds the file at the given path.
     * Pass 1: Cryptographic random bytes (CSPRNG)
     * Pass 2: Bitwise inversion (0xFF)
     * Pass 3: Zeroes (0x00)
     * Truncates file length to 0, forces OS disk synchronization, and deletes the file.
     *
     * @param targetPath Path to the file to be wiped
     * @return true if file was successfully wiped and deleted, false if file did not exist
     * @throws IOException on I/O error during wiping
     */
    public static boolean shred(Path targetPath) throws IOException {
        if (targetPath == null || !Files.exists(targetPath)) {
            return false;
        }

        if (Files.isDirectory(targetPath)) {
            throw new IllegalArgumentException("Target must be a regular file, not a directory: " + targetPath);
        }

        long fileLength = Files.size(targetPath);
        if (fileLength > 0) {
            byte[] buffer = new byte[BUFFER_SIZE];
            ByteBuffer byteBuffer = ByteBuffer.wrap(buffer);

            try (RandomAccessFile raf = new RandomAccessFile(targetPath.toFile(), "rws");
                 FileChannel channel = raf.getChannel()) {

                // Pass 1: Cryptographic Random
                wipeWithPattern(channel, byteBuffer, buffer, fileLength, PatternMode.RANDOM);
                channel.force(true);

                // Pass 2: Bitwise 0xFF
                wipeWithPattern(channel, byteBuffer, buffer, fileLength, PatternMode.ONES);
                channel.force(true);

                // Pass 3: Zeroes (0x00)
                wipeWithPattern(channel, byteBuffer, buffer, fileLength, PatternMode.ZEROS);
                channel.force(true);

                // Truncate to 0
                channel.truncate(0);
                channel.force(true);
            }
        }

        // Unlink and delete file
        boolean deleted = Files.deleteIfExists(targetPath);
        log.info("CryptoShredder successfully wiped and deleted: {} (length: {} bytes)", targetPath, fileLength);
        return deleted;
    }

    /**
     * Zero-out sensitive memory buffers (keys, tokens, decrypted chunks).
     */
    public static void wipeMemory(byte[] sensitiveData) {
        if (sensitiveData != null) {
            Arrays.fill(sensitiveData, (byte) 0);
        }
    }

    private static void wipeWithPattern(FileChannel channel, ByteBuffer byteBuffer, byte[] buffer,
                                        long fileLength, PatternMode mode) throws IOException {
        channel.position(0);
        long written = 0;

        while (written < fileLength) {
            int chunk = (int) Math.min(buffer.length, fileLength - written);
            switch (mode) {
                case RANDOM -> SECURE_RANDOM.nextBytes(buffer);
                case ONES -> Arrays.fill(buffer, 0, chunk, (byte) 0xFF);
                case ZEROS -> Arrays.fill(buffer, 0, chunk, (byte) 0x00);
            }

            byteBuffer.position(0);
            byteBuffer.limit(chunk);
            while (byteBuffer.hasRemaining()) {
                channel.write(byteBuffer);
            }
            written += chunk;
        }
    }

    private enum PatternMode {
        RANDOM,
        ONES,
        ZEROS
    }
}
