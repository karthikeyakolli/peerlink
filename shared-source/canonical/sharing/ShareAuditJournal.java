package org.peerlink.core.sharing;

import org.peerlink.protocol.v1.ShareAuditEvent;

import java.util.*;
import java.util.concurrent.ConcurrentLinkedDeque;
import java.util.stream.Collectors;

public final class ShareAuditJournal {
    public static final int DEFAULT_MAX_ENTRIES = 10_000;
    private final int maxEntries;
    private final Deque<ShareAuditRecord> records = new ConcurrentLinkedDeque<>();

    public ShareAuditJournal() { this(DEFAULT_MAX_ENTRIES); }
    public ShareAuditJournal(int maxEntries) { this.maxEntries = maxEntries; }

    public void log(ShareAuditRecord record) {
        if (record == null) return;
        records.addFirst(record);
        while (records.size() > maxEntries) records.pollLast();
    }

    public void log(String shareId, String actorPeerId, ShareAuditEvent event, String operationId, String detail) {
        log(new ShareAuditRecord(System.currentTimeMillis(), shareId, actorPeerId, event, operationId, detail));
    }

    public List<ShareAuditRecord> getAllRecords() { return new ArrayList<>(records); }

    public List<ShareAuditRecord> findByShareId(String shareId) {
        if (shareId == null) return List.of();
        return records.stream().filter(r -> shareId.equals(r.shareId())).collect(Collectors.toList());
    }

    public List<ShareAuditRecord> findByEvent(ShareAuditEvent event) {
        return records.stream().filter(r -> r.event() == event).collect(Collectors.toList());
    }

    public List<ShareAuditRecord> findByActor(String actorPeerId) {
        if (actorPeerId == null) return List.of();
        return records.stream().filter(r -> actorPeerId.equals(r.actorPeerId())).collect(Collectors.toList());
    }

    public int size() { return records.size(); }
    public void clear() { records.clear(); }
}