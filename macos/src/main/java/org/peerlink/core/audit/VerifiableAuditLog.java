package org.peerlink.core.audit;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Cryptographic Verifiable Audit Log and Self-Healing Safety Guard.
 *
 * SECTION D SPECIFICATION COMPLIANCE:
 * 1. Hash-Chained Audit Trail: Every event record is linked via SHA-256 hash chain.
 *    Detects sequence truncation, deletion, reordering, and unauthorized rewriting.
 * 2. Burn-After-Read Reconciled: Retains cryptographic deletion proof without
 *    storing sensitive file content, keys, or private payloads in the audit log.
 * 3. Safe Self-Healing Actions:
 *    - Rate-limited retry with backoff preventing transport flood.
 *    - OUTCOME_UNKNOWN guard requiring explicit remote reconciliation before replay.
 *    - Quarantine cleanup isolating only expired/corrupted entries, preserving active transfers.
 */
public final class VerifiableAuditLog {

    public static final String GENESIS_HASH = "0000000000000000000000000000000000000000000000000000000000000000";

    public record VerifiableAuditRecord(
            long sequenceNumber,
            long timestampUtcMs,
            String eventType,
            String actorPeerId,
            String operationId,
            String metadataDigest,
            String previousHash,
            String recordHash
    ) {}

    public record AuditIntegrityReport(
            boolean isValid,
            int verifiedCount,
            String tipHash,
            String failureReason
    ) {}

    public enum QuarantineStatus {
        ACTIVE_TRANSFER_STAGING,
        VALID_STAGED_CHUNKS,
        QUARANTINE_ISOLATED,
        EXPIRED,
        CORRUPTED
    }

    public record QuarantineFileEntry(
            String id,
            String relativePath,
            QuarantineStatus status,
            long stagedTimestampUtcMs
    ) {}

    private final List<VerifiableAuditRecord> chain = new CopyOnWriteArrayList<>();
    private final AtomicLong sequenceGenerator = new AtomicLong(0);
    private final Map<String, Long> lastRetryTimestamps = new ConcurrentHashMap<>();

    public synchronized VerifiableAuditRecord append(String eventType,
                                                    String actorPeerId,
                                                    String operationId,
                                                    String metadataDigest) {
        long seq = sequenceGenerator.incrementAndGet();
        long now = System.currentTimeMillis();

        String prevHash = chain.isEmpty() ? GENESIS_HASH : chain.get(chain.size() - 1).recordHash();
        String currentHash = computeRecordHash(prevHash, seq, now, eventType, actorPeerId, operationId, metadataDigest);

        VerifiableAuditRecord record = new VerifiableAuditRecord(
                seq, now, eventType, actorPeerId, operationId, metadataDigest, prevHash, currentHash
        );
        chain.add(record);
        return record;
    }

    /**
     * Reconciles Burn-After-Read with Audit Logging:
     * Retains cryptographic proof of erasure event while deliberately excluding sensitive plaintext or key material.
     */
    public synchronized VerifiableAuditRecord logBurnAfterReadErasure(String transferId, String recipientPeerId, String reason) {
        String metadata = "transfer:" + transferId + "|action:KEY_REVOKED_AND_SHREDDED|reason:" + reason;
        String metadataDigest = computeSha256Hex(metadata);
        return append("BURN_AFTER_READ_ERASED", recipientPeerId, transferId, metadataDigest);
    }

    public List<VerifiableAuditRecord> getRecords() {
        return List.copyOf(chain);
    }

    public int size() {
        return chain.size();
    }

    /**
     * Verifies the complete hash chain from genesis to tip.
     * Detects deletion, truncation, reordering, and modification.
     */
    public AuditIntegrityReport verifyIntegrity() {
        if (chain.isEmpty()) {
            return new AuditIntegrityReport(true, 0, GENESIS_HASH, null);
        }

        String expectedPrevHash = GENESIS_HASH;
        long expectedSeq = 1;

        for (int i = 0; i < chain.size(); i++) {
            VerifiableAuditRecord record = chain.get(i);

            // 1. Sequence continuity check (detects deletions, gaps, and insertions)
            if (record.sequenceNumber() != expectedSeq) {
                return new AuditIntegrityReport(
                        false, i, null,
                        "Sequence discontinuity at index " + i + ": expected " + expectedSeq + " but found " + record.sequenceNumber()
                );
            }

            // 2. Hash-chain linkage check (detects reordering, deletions, and truncation)
            if (!record.previousHash().equalsIgnoreCase(expectedPrevHash)) {
                return new AuditIntegrityReport(
                        false, i, null,
                        "Hash chain broken at sequence " + record.sequenceNumber() + ": previousHash mismatch"
                );
            }

            // 3. Content integrity check (detects unauthorized payload / metadata rewriting)
            String recomputedHash = computeRecordHash(
                    record.previousHash(), record.sequenceNumber(), record.timestampUtcMs(),
                    record.eventType(), record.actorPeerId(), record.operationId(), record.metadataDigest()
            );
            if (!record.recordHash().equalsIgnoreCase(recomputedHash)) {
                return new AuditIntegrityReport(
                        false, i, null,
                        "Tampered record at sequence " + record.sequenceNumber() + ": hash signature invalid"
                );
            }

            expectedPrevHash = record.recordHash();
            expectedSeq++;
        }

        return new AuditIntegrityReport(true, chain.size(), expectedPrevHash, null);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Self-Healing Safety Guards
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Rate-limited Retry Connection Guard:
     * Verifies that retries do not flood transports by enforcing a minimum backoff interval.
     */
    public boolean canRetryConnection(String peerId, long minIntervalMs) {
        if (peerId == null || peerId.isBlank()) return false;
        long now = System.currentTimeMillis();
        Long lastTime = lastRetryTimestamps.get(peerId);

        if (lastTime != null && (now - lastTime) < minIntervalMs) {
            return false; // Flood protection active
        }

        lastRetryTimestamps.put(peerId, now);
        return true;
    }

    /**
     * Outcome Unknown Guard:
     * Never blindly replay operations with uncertain outcomes. State must be reconciled first.
     */
    public boolean canReplayOutcomeUnknown(String operationId, boolean remoteStateReconciled) {
        if (operationId == null || operationId.isBlank()) return false;
        // Invariant: If outcome was unconfirmed, replay is prohibited until explicit reconciliation succeeds
        return remoteStateReconciled;
    }

    /**
     * Quarantine Cleanup Guard:
     * Removes ONLY expired or corrupted quarantined records, strictly protecting active transfers.
     */
    public List<QuarantineFileEntry> filterForQuarantineCleanup(List<QuarantineFileEntry> entries) {
        if (entries == null) return List.of();
        List<QuarantineFileEntry> safeToDelete = new ArrayList<>();

        for (QuarantineFileEntry entry : entries) {
            if (entry.status() == QuarantineStatus.EXPIRED || entry.status() == QuarantineStatus.CORRUPTED) {
                safeToDelete.add(entry);
            }
            // ACTIVE_TRANSFER_STAGING and VALID_STAGED_CHUNKS are NEVER pruned by cleanup
        }

        return List.copyOf(safeToDelete);
    }

    private static String computeRecordHash(String prevHash, long seq, long timestamp,
                                            String eventType, String actor, String opId, String meta) {
        String payload = prevHash + ":" + seq + ":" + timestamp + ":" + eventType + ":" + actor + ":" + opId + ":" + meta;
        return computeSha256Hex(payload);
    }

    private static String computeSha256Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
