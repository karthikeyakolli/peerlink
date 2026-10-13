package org.peerlink.core.backup;

import org.peerlink.core.model.ContentHash;

import java.io.IOException;
import java.nio.file.*;
import java.security.GeneralSecurityException;
import java.util.*;

/**
 * Executes a restore plan.
 *
 * CRITICAL RESTORE RULES:
 * 1. Restore creates a NEW current version. Never rewrite history.
 * 2. Restore must verify data before exposing it as a completed restored object.
 * 3. Never silently overwrite an existing file when conflict policy requires a separate result.
 * 4. Verify destination permissions and disk capacity prior to modifying target tree.
 */
public final class RestoreExecutor {

    public static RestoreExecutionResult execute(RestorePlan plan,
                                                 BackupTarget target,
                                                 byte[] blindDecryptionKey,
                                                 long currentLocalVersionSequence) throws IOException {
        Objects.requireNonNull(plan, "plan cannot be null");
        Objects.requireNonNull(target, "target cannot be null");

        String restoreId = "rst_" + UUID.randomUUID().toString().replace("-", "");
        List<String> errors = new ArrayList<>();
        Path canonicalTarget = plan.targetDirectory().toAbsolutePath().normalize();

        // 1. Validate Target Permissions
        if (Files.exists(canonicalTarget) && !Files.isWritable(canonicalTarget)) {
            return new RestoreExecutionResult(restoreId, plan.backupId(), false, 0, 0,
                    currentLocalVersionSequence, List.of("Restore aborted: destination directory is not writable: " + canonicalTarget));
        }

        // 2. Validate Disk Capacity
        try {
            if (Files.exists(canonicalTarget)) {
                FileStore fileStore = Files.getFileStore(canonicalTarget);
                long usableSpace = fileStore.getUsableSpace();
                if (usableSpace > 0 && usableSpace < plan.totalBytesToRestore()) {
                    return new RestoreExecutionResult(restoreId, plan.backupId(), false, 0, 0,
                            currentLocalVersionSequence, List.of("Restore aborted: insufficient disk capacity (required "
                            + plan.totalBytesToRestore() + " bytes, usable " + usableSpace + " bytes)"));
                }
            }
        } catch (Exception ignored) {
            // Memory or virtual stores may not provide getFileStore
        }

        // 3. Execution-Time Conflict Validation under FAIL_ON_CONFLICT
        if (plan.conflictPolicy() == RestoreConflictPolicy.FAIL_ON_CONFLICT) {
            if (!plan.conflicts().isEmpty()) {
                return new RestoreExecutionResult(restoreId, plan.backupId(), false, 0, 0,
                        currentLocalVersionSequence, List.of("Restore aborted: conflicts present under FAIL_ON_CONFLICT"));
            }

            for (HistoricalVersion item : plan.itemsToRestore().values()) {
                Path destFile = resolveSafePath(canonicalTarget, item.getRelativePath());
                if (Files.exists(destFile)) {
                    byte[] existingBytes = Files.readAllBytes(destFile);
                    if (item.getContentHash() != null && !item.getContentHash().matches(existingBytes)) {
                        return new RestoreExecutionResult(restoreId, plan.backupId(), false, 0, 0,
                                currentLocalVersionSequence, List.of("Restore aborted: conflicting file already exists at destination: " + item.getRelativePath()));
                    }
                }
            }
        }

        int restoredCount = 0;
        long restoredBytes = 0;
        // Invariant: Restore creates a NEW version with higher version sequence!
        long newVersionSequence = currentLocalVersionSequence + 1;

        for (HistoricalVersion item : plan.itemsToRestore().values()) {
            Path stagingFile = null;
            try {
                if (!target.hasPayload(item.getStorageHash())) {
                    throw new IOException("Missing storage payload on target for " + item.getRelativePath() + ": " + item.getStorageHash());
                }

                byte[] storedPayload = target.retrievePayload(item.getStorageHash());

                // Verify storage payload checksum
                ContentHash payloadHash = ContentHash.computeSha256(storedPayload);
                if (!payloadHash.getHexString().equalsIgnoreCase(item.getStorageHash())) {
                    throw new IOException("Corrupted payload on target storage for " + item.getRelativePath());
                }

                byte[] fileBytes;
                if (item.isEncrypted()) {
                    if (blindDecryptionKey == null) {
                        throw new IOException("Cannot restore blind encrypted item without decryption key: " + item.getRelativePath());
                    }
                    fileBytes = BlindPayloadCipher.decrypt(storedPayload, blindDecryptionKey);
                } else {
                    fileBytes = storedPayload;
                }

                // Verify plaintext content integrity
                if (item.getContentHash() != null && !item.getContentHash().matches(fileBytes)) {
                    throw new IOException("Content verification failed for " + item.getRelativePath());
                }

                Path destFile = resolveSafePath(canonicalTarget, item.getRelativePath());

                // Apply conflict policy for destination collisions
                if (Files.exists(destFile)) {
                    if (plan.conflictPolicy() == RestoreConflictPolicy.FAIL_ON_CONFLICT) {
                        throw new IOException("Destination file collision under FAIL_ON_CONFLICT: " + item.getRelativePath());
                    } else if (plan.conflictPolicy() == RestoreConflictPolicy.RESTORE_TO_ALTERNATIVE_PATH) {
                        destFile = resolveUniqueAlternativePath(canonicalTarget, item.getRelativePath());
                    }
                    // For OVERWRITE_WITH_NEW_VERSION: destFile is overwritten atomically via verified staging below
                }

                if (destFile.getParent() != null) {
                    Files.createDirectories(destFile.getParent());
                }

                // Stage write and verify on disk BEFORE exposing as completed restored object
                stagingFile = destFile.getParent().resolve("." + destFile.getFileName() + ".part." + UUID.randomUUID() + ".tmp");
                Files.write(stagingFile, fileBytes, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE);

                // Disk Readback Verification
                byte[] diskBytes = Files.readAllBytes(stagingFile);
                if (diskBytes.length != fileBytes.length) {
                    throw new IOException("Staged file write length mismatch for " + item.getRelativePath());
                }
                if (item.getContentHash() != null && !item.getContentHash().matches(diskBytes)) {
                    throw new IOException("Staged file disk readback verification failed for " + item.getRelativePath());
                }

                // Atomically expose completed verified file
                try {
                    Files.move(stagingFile, destFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
                } catch (AtomicMoveNotSupportedException e) {
                    Files.move(stagingFile, destFile, StandardCopyOption.REPLACE_EXISTING);
                }

                restoredCount++;
                restoredBytes += fileBytes.length;
            } catch (GeneralSecurityException e) {
                errors.add("Decryption failed for " + item.getRelativePath() + ": " + e.getMessage());
            } catch (Exception e) {
                errors.add("Failed restoring " + item.getRelativePath() + ": " + e.getMessage());
            } finally {
                if (stagingFile != null) {
                    try {
                        Files.deleteIfExists(stagingFile);
                    } catch (Exception ignored) {}
                }
            }
        }

        boolean success = errors.isEmpty();
        return new RestoreExecutionResult(restoreId, plan.backupId(), success, restoredCount,
                restoredBytes, newVersionSequence, errors);
    }

    private static Path resolveSafePath(Path canonicalTarget, String relPath) {
        if (relPath == null || relPath.isBlank() || relPath.contains("\0") || relPath.contains(":")
                || relPath.startsWith("/") || relPath.startsWith("\\")
                || (relPath.length() >= 2 && Character.isLetter(relPath.charAt(0)) && relPath.charAt(1) == ':')) {
            throw new SecurityException("Illegal characters or absolute prefix in relative path: " + relPath);
        }

        Path normalizedRel = Path.of(relPath).normalize();
        for (Path part : normalizedRel) {
            if ("..".equals(part.toString())) {
                throw new SecurityException("Parent directory traversal prohibited: " + relPath);
            }
        }

        Path destFile = canonicalTarget.resolve(normalizedRel).normalize();
        if (!destFile.startsWith(canonicalTarget)) {
            throw new SecurityException("Resolved restore path escapes target directory: " + relPath);
        }
        return destFile;
    }

    private static Path resolveUniqueAlternativePath(Path canonicalTarget, String relPath) {
        long timestamp = System.currentTimeMillis();
        Path baseDest = resolveSafePath(canonicalTarget, relPath);
        String fileName = baseDest.getFileName().toString();
        Path parent = baseDest.getParent();

        Path candidate = parent.resolve(fileName + ".restored." + timestamp).normalize();
        int counter = 1;
        while (Files.exists(candidate)) {
            candidate = parent.resolve(fileName + ".restored." + timestamp + "." + counter).normalize();
            counter++;
        }
        return candidate;
    }
}