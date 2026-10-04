package org.peerlink.core.access;

import java.util.*;
import java.util.concurrent.ConcurrentLinkedDeque;
import java.util.stream.Collectors;

/**
 * Audit journal maintaining historical records of all remote access attempts.
 */
public final class AccessAuditJournal {

    public static final int DEFAULT_MAX_LOG_ENTRIES = 10_000;

    private final int maxEntries;
    private final Deque<AccessAuditRecord> records = new ConcurrentLinkedDeque<>();

    public AccessAuditJournal() {
        this(DEFAULT_MAX_LOG_ENTRIES);
    }

    public AccessAuditJournal(int maxEntries) {
        this.maxEntries = maxEntries;
    }

    public void log(AccessAuditRecord record) {
        if (record == null) return;
        records.addFirst(record);
        while (records.size() > maxEntries) {
            records.pollLast();
        }
    }

    public List<AccessAuditRecord> getAllRecords() {
        return new ArrayList<>(records);
    }

    public List<AccessAuditRecord> findByPeerId(String peerId) {
        if (peerId == null) return List.of();
        return records.stream()
                .filter(r -> peerId.equals(r.requesterPeerId()))
                .collect(Collectors.toList());
    }

    public List<AccessAuditRecord> findByOutcome(AccessAuditRecord.AuditOutcome outcome) {
        return records.stream()
                .filter(r -> r.outcome() == outcome)
                .collect(Collectors.toList());
    }

    public List<AccessAuditRecord> findByShareId(String shareId) {
        if (shareId == null) return List.of();
        return records.stream()
                .filter(r -> shareId.equals(r.shareId()))
                .collect(Collectors.toList());
    }

    public int size() {
        return records.size();
    }

    public void clear() {
        records.clear();
    }
}
