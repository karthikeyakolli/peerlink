package org.peerlink.core.backup;

import org.peerlink.core.model.ContentHash;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.*;

/**
 * Backup verifier.
 * Proves that backup data is reconstructable and uncorrupted.
 */
public final class BackupVerifier {

    public static BackupVerificationReport verify(BackupTarget target,
                                                  BackupManifest manifest,
                                                  boolean deep,
                                                  byte[] blindDecryptionKey) {
        Objects.requireNonNull(target, "target cannot be null");
        Objects.requireNonNull(manifest, "manifest cannot be null");

        List<String> missingPayloads = new ArrayList<>();
        List<String> corruptedItems = new ArrayList<>();
        long verifiedFiles = 0;
        long verifiedBytes = 0;

        if (!manifest.verifyIntegrity()) {
            corruptedItems.add("Manifest digest mismatch for backupId " + manifest.getBackupId() + ": integrity check failed");
        }

        for (HistoricalVersion item : manifest.getItems().values()) {
            if (item.isDeleted()) continue;

            String storageHash = item.getStorageHash();
            if (!target.hasPayload(storageHash)) {
                missingPayloads.add(item.getRelativePath() + " (missing payload: " + storageHash + ")");
                continue;
            }

            if (deep) {
                try {
                    byte[] storedData = target.retrievePayload(storageHash);
                    // Verify storage hash
                    ContentHash computedStorageHash = ContentHash.computeSha256(storedData);
                    if (!computedStorageHash.getHexString().equalsIgnoreCase(storageHash)) {
                        corruptedItems.add(item.getRelativePath() + " (storage hash mismatch)");
                        continue;
                    }

                    // If encrypted and key provided, decrypt and verify content hash
                    if (item.isEncrypted()) {
                        if (blindDecryptionKey != null) {
                            byte[] plaintext = BlindPayloadCipher.decrypt(storedData, blindDecryptionKey);
                            if (item.getContentHash() != null && !item.getContentHash().matches(plaintext)) {
                                corruptedItems.add(item.getRelativePath() + " (plaintext content hash mismatch)");
                                continue;
                            }
                        }
                    } else {
                        // Plaintext target
                        if (item.getContentHash() != null && !item.getContentHash().matches(storedData)) {
                            corruptedItems.add(item.getRelativePath() + " (content hash mismatch)");
                            continue;
                        }
                    }

                    verifiedFiles++;
                    verifiedBytes += item.getSizeBytes();
                } catch (IOException | GeneralSecurityException e) {
                    corruptedItems.add(item.getRelativePath() + " (" + e.getMessage() + ")");
                }
            } else {
                verifiedFiles++;
                verifiedBytes += item.getSizeBytes();
            }
        }

        boolean passed = missingPayloads.isEmpty() && corruptedItems.isEmpty();
        return new BackupVerificationReport(passed, verifiedFiles, verifiedBytes, missingPayloads, corruptedItems, passed);
    }
}