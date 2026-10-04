package org.peerlink.core.backup;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.GeneralSecurityException;
import java.util.*;

/**
 * Executes a restore plan.
 *
 * CRITICAL RESTORE RULE:
 * Restore creates a NEW current version. Never rewrite history.
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

        if (!plan.conflicts().isEmpty() && plan.conflictPolicy() == RestoreConflictPolicy.FAIL_ON_CONFLICT) {
            return new RestoreExecutionResult(restoreId, plan.backupId(), false, 0, 0,
                    currentLocalVersionSequence, List.of("Restore aborted: conflicts present under FAIL_ON_CONFLICT"));
        }

        int restoredCount = 0;
        long restoredBytes = 0;
        // Invariant: Restore creates a NEW version with higher version sequence!
        long newVersionSequence = currentLocalVersionSequence + 1;

        for (HistoricalVersion item : plan.itemsToRestore().values()) {
            try {
                byte[] storedPayload = target.retrievePayload(item.getStorageHash());
                byte[] fileBytes;

                if (item.isEncrypted()) {
                    if (blindDecryptionKey == null) {
                        throw new IOException("Cannot restore blind encrypted item without decryption key");
                    }
                    fileBytes = BlindPayloadCipher.decrypt(storedPayload, blindDecryptionKey);
                } else {
                    fileBytes = storedPayload;
                }

                // Verify integrity
                if (item.getContentHash() != null && !item.getContentHash().matches(fileBytes)) {
                    throw new IOException("Content verification failed for " + item.getRelativePath());
                }

                // Validate relative path against traversal attacks
                String relPath = item.getRelativePath();
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

                Path canonicalTarget = plan.targetDirectory().toAbsolutePath().normalize();
                Path destFile = canonicalTarget.resolve(normalizedRel).normalize();
                if (!destFile.startsWith(canonicalTarget)) {
                    throw new SecurityException("Resolved restore path escapes target directory: " + relPath);
                }

                if (Files.exists(destFile) && plan.conflictPolicy() == RestoreConflictPolicy.RESTORE_TO_ALTERNATIVE_PATH) {
                    destFile = canonicalTarget.resolve(normalizedRel + ".restored." + System.currentTimeMillis()).normalize();
                    if (!destFile.startsWith(canonicalTarget)) {
                        throw new SecurityException("Alternative restore path escapes target directory: " + relPath);
                    }
                }

                if (destFile.getParent() != null) {
                    Files.createDirectories(destFile.getParent());
                }

                Files.write(destFile, fileBytes);
                restoredCount++;
                restoredBytes += fileBytes.length;
            } catch (GeneralSecurityException e) {
                errors.add("Decryption failed for " + item.getRelativePath() + ": " + e.getMessage());
            } catch (Exception e) {
                errors.add("Failed restoring " + item.getRelativePath() + ": " + e.getMessage());
            }
        }

        boolean success = errors.isEmpty();
        return new RestoreExecutionResult(restoreId, plan.backupId(), success, restoredCount,
                restoredBytes, newVersionSequence, errors);
    }
}