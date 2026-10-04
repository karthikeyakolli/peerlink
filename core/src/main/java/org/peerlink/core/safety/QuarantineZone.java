package org.peerlink.core.safety;

import org.peerlink.core.model.ContentHash;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Isolated staging directory for inbound files prior to integrity, scanning, and policy verification.
 * Invariant: Files in quarantine cannot be opened or executed by users.
 */
public final class QuarantineZone {
    private final Path quarantineDirectory;
    private final Map<String, QuarantineRecord> records = new ConcurrentHashMap<>();

    public QuarantineZone(Path quarantineDirectory) throws IOException {
        this.quarantineDirectory = Objects.requireNonNull(quarantineDirectory, "quarantineDirectory cannot be null");
        if (!Files.exists(quarantineDirectory)) {
            Files.createDirectories(quarantineDirectory);
        }
    }

    public QuarantineRecord stageInbound(byte[] content, String relativePath, ContentHash expectedHash, String sourcePeerId) throws IOException {
        String qId = "q_" + UUID.randomUUID().toString().replace("-", "");
        Path stagedFile = quarantineDirectory.resolve(qId + ".stage");
        Files.write(stagedFile, content);

        QuarantineRecord record = new QuarantineRecord(
                qId, stagedFile, relativePath, expectedHash, content.length,
                sourcePeerId, System.currentTimeMillis(), QuarantineRecord.QuarantineStatus.STAGED
        );
        records.put(qId, record);
        return record;
    }

    public boolean verifyIntegrity(QuarantineRecord record) throws IOException {
        if (!Files.exists(record.stagedFile())) return false;
        byte[] bytes = Files.readAllBytes(record.stagedFile());
        ContentHash computed = ContentHash.computeSha256(bytes);
        return record.expectedHash() != null && record.expectedHash().equals(computed);
    }

    public Path commitFile(QuarantineRecord record, Path destinationDirectory) throws IOException {
        if (record.status() == QuarantineRecord.QuarantineStatus.QUARANTINED_MALICIOUS) {
            throw new SecurityException("Cannot commit malicious file from quarantine: " + record.quarantineId());
        }
        String rawRel = record.originalRelativePath();
        if (rawRel == null || rawRel.isBlank() || rawRel.contains("\0") || rawRel.contains(":")
                || rawRel.startsWith("/") || rawRel.startsWith("\\")
                || (rawRel.length() >= 2 && Character.isLetter(rawRel.charAt(0)) && rawRel.charAt(1) == ':')) {
            throw new SecurityException("Path traversal attempt in quarantine record: " + rawRel);
        }

        Path normalizedRel = Path.of(rawRel).normalize();
        for (Path part : normalizedRel) {
            if ("..".equals(part.toString())) {
                throw new SecurityException("Parent directory traversal prohibited: " + rawRel);
            }
        }

        Path canonicalDest = destinationDirectory.toAbsolutePath().normalize();
        Path targetPath = canonicalDest.resolve(normalizedRel).normalize();
        if (!targetPath.startsWith(canonicalDest)) {
            throw new SecurityException("Committed path escapes destination directory: " + rawRel);
        }

        if (targetPath.getParent() != null) {
            Files.createDirectories(targetPath.getParent());
        }
        Files.move(record.stagedFile(), targetPath, StandardCopyOption.REPLACE_EXISTING);
        records.put(record.quarantineId(), record.withStatus(QuarantineRecord.QuarantineStatus.COMMITTED));
        return targetPath;
    }

    public void isolateMalicious(QuarantineRecord record) throws IOException {
        Path isolatedPath = quarantineDirectory.resolve(record.quarantineId() + ".malicious.quarantined");
        Files.move(record.stagedFile(), isolatedPath, StandardCopyOption.REPLACE_EXISTING);
        records.put(record.quarantineId(), record.withStatus(QuarantineRecord.QuarantineStatus.QUARANTINED_MALICIOUS));
    }

    public void rejectAndDelete(QuarantineRecord record) throws IOException {
        if (Files.exists(record.stagedFile())) {
            Files.delete(record.stagedFile());
        }
        records.put(record.quarantineId(), record.withStatus(QuarantineRecord.QuarantineStatus.REJECTED_DELETED));
    }

    public Optional<QuarantineRecord> getRecord(String quarantineId) {
        return Optional.ofNullable(records.get(quarantineId));
    }

    public Path getQuarantineDirectory() {
        return quarantineDirectory;
    }
}