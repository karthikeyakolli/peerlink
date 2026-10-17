package org.peerlink.core.transfer.cdc;

import org.peerlink.core.transfer.FileManifestBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.util.Map;

/**
 * Reconstructs target files safely from a combination of local base chunks
 * and wire-transferred delta chunks.
 *
 * <p>Invariant:
 * Never mutates in-place. Staging occurs in an isolated temporary file,
 * verifies SHA-256 cryptographically on every chunk and on the final file,
 * and atomically moves to the destination path only after passing all integrity checks.
 */
public final class DeltaReconstructor {

    private static final Logger log = LoggerFactory.getLogger(DeltaReconstructor.class);

    private DeltaReconstructor() {}

    /**
     * Reconstruct a target file using base local file and newly received wire chunks.
     *
     * @param basePath Path to the local base file (can be null if completely new file)
     * @param baseManifest Manifest of the base file
     * @param targetManifest Manifest describing the expected target file structure
     * @param wireTransferredChunks In-memory map of newly received chunks keyed by SHA-256
     * @param destinationPath Final destination file path
     * @param expectedSha256 Expected whole-file SHA-256 hash (or null to skip final check)
     * @throws IOException on I/O error
     * @throws SecurityException on hash or chunk verification failure
     */
    public static void reconstruct(
            Path basePath,
            DeltaSyncManifest baseManifest,
            DeltaSyncManifest targetManifest,
            Map<String, byte[]> wireTransferredChunks,
            Path destinationPath,
            String expectedSha256) throws IOException {

        Path parent = destinationPath.getParent();
        if (parent != null && !Files.exists(parent)) {
            Files.createDirectories(parent);
        }

        Path stagingPath = destinationPath.resolveSibling(destinationPath.getFileName().toString() + ".staging." + System.nanoTime());

        try {
            try (FileChannel outChannel = FileChannel.open(
                    stagingPath,
                    StandardOpenOption.CREATE_NEW,
                    StandardOpenOption.WRITE)) {

                FileChannel baseChannel = null;
                if (basePath != null && Files.exists(basePath)) {
                    baseChannel = FileChannel.open(basePath, StandardOpenOption.READ);
                }

                try {
                    for (ContentDefinedChunk targetChunk : targetManifest.chunks()) {
                        String requiredSha = targetChunk.sha256Hex();

                        if (wireTransferredChunks.containsKey(requiredSha)) {
                            // 1. From wire transmission
                            byte[] chunkData = wireTransferredChunks.get(requiredSha);
                            String actualSha = FileManifestBuilder.calculateSha256Hex(chunkData);
                            if (!actualSha.equalsIgnoreCase(requiredSha)) {
                                throw new SecurityException(String.format(
                                        "Corrupted wire chunk for index %d: expected SHA-256 %s, got %s",
                                        targetChunk.chunkIndex(), requiredSha, actualSha));
                            }
                            outChannel.write(ByteBuffer.wrap(chunkData));
                        } else if (baseManifest != null && baseManifest.containsChunk(requiredSha) && baseChannel != null) {
                            // 2. From local base file
                            ContentDefinedChunk baseChunk = baseManifest.getChunk(requiredSha);
                            ByteBuffer buffer = ByteBuffer.allocate(baseChunk.lengthBytes());
                            baseChannel.position(baseChunk.offsetBytes());
                            int read = baseChannel.read(buffer);
                            if (read != baseChunk.lengthBytes()) {
                                throw new IOException("Failed to read complete chunk from base file at offset " + baseChunk.offsetBytes());
                            }
                            buffer.flip();

                            byte[] localBytes = new byte[read];
                            buffer.get(localBytes);
                            String actualSha = FileManifestBuilder.calculateSha256Hex(localBytes);
                            if (!actualSha.equalsIgnoreCase(requiredSha)) {
                                throw new SecurityException("Local base file chunk corrupted at offset " + baseChunk.offsetBytes());
                            }
                            outChannel.write(ByteBuffer.wrap(localBytes));
                        } else {
                            throw new IllegalStateException("Missing required chunk hash: " + requiredSha);
                        }
                    }
                } finally {
                    if (baseChannel != null) {
                        baseChannel.close();
                    }
                }
            }

            // 3. Final whole-file SHA-256 verification
            if (expectedSha256 != null && !expectedSha256.isBlank()) {
                String computedFinalSha = FileManifestBuilder.calculateSha256Hex(stagingPath);
                if (!computedFinalSha.equalsIgnoreCase(expectedSha256)) {
                    throw new SecurityException(String.format(
                            "Reconstructed file SHA-256 mismatch: expected %s, got %s",
                            expectedSha256, computedFinalSha));
                }
            }

            // 4. Atomic move to target destination
            Files.move(stagingPath, destinationPath, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
            log.info("Successfully reconstructed delta file: {} ({} bytes)", destinationPath, Files.size(destinationPath));

        } catch (Throwable t) {
            // Guarantee staging cleanup on error
            try {
                Files.deleteIfExists(stagingPath);
            } catch (IOException ignored) {}
            throw t;
        }
    }
}
