package org.peerlink.desktop.storage;

import org.peerlink.core.event.NodeEvent;
import org.peerlink.core.event.NodeEventBus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;

/**
 * Resource limits policy for the Desktop Local Node.
 *
 * <p>Defines and enforces upper bounds on:
 * <ul>
 *   <li>Maximum open (non-terminal) concurrent operations.</li>
 *   <li>Maximum journal entry count before archival is required.</li>
 *   <li>Maximum database file size before a warning is emitted.</li>
 * </ul>
 *
 * <p>When a limit is approached (warning threshold) or reached (hard limit), an
 * event is published to the {@link NodeEventBus}. Hard limits cause the operation
 * to be refused with a {@link ResourceLimitException}.
 *
 * <p>These limits are conservative defaults suitable for a development/prototype
 * node. Production tuning should read from NodeConfiguration.
 */
public final class ResourceLimitsPolicy {
    private static final Logger log = LoggerFactory.getLogger(ResourceLimitsPolicy.class);

    // Hard limits
    public static final int MAX_OPEN_OPERATIONS = 100;
    public static final int MAX_JOURNAL_ENTRIES = 10_000;
    public static final long MAX_DATABASE_SIZE_BYTES = 256L * 1024 * 1024; // 256 MB

    // Warning thresholds (80% of hard limit)
    private static final int WARN_OPEN_OPERATIONS = (int) (MAX_OPEN_OPERATIONS * 0.8);
    private static final int WARN_JOURNAL_ENTRIES = (int) (MAX_JOURNAL_ENTRIES * 0.8);
    private static final long WARN_DATABASE_SIZE_BYTES = (long) (MAX_DATABASE_SIZE_BYTES * 0.8);

    private final NodeEventBus eventBus;

    public ResourceLimitsPolicy(NodeEventBus eventBus) {
        this.eventBus = eventBus;
    }

    /**
     * Check whether a new operation can be accepted.
     *
     * @param currentOpenOperations number of currently non-terminal operations
     * @throws ResourceLimitException if the hard limit is reached
     */
    public void checkCanAcceptOperation(int currentOpenOperations) {
        if (currentOpenOperations >= MAX_OPEN_OPERATIONS) {
            throw new ResourceLimitException(
                    "Maximum concurrent operations reached: " + currentOpenOperations + "/" + MAX_OPEN_OPERATIONS);
        }
        if (currentOpenOperations >= WARN_OPEN_OPERATIONS) {
            log.warn("Approaching open-operations limit: {}/{}", currentOpenOperations, MAX_OPEN_OPERATIONS);
            publishWarning(NodeEvent.ResourceKind.OPEN_OPERATIONS_COUNT,
                    currentOpenOperations, MAX_OPEN_OPERATIONS,
                    "Approaching concurrent operation limit");
        }
    }

    /**
     * Check journal entry count and warn if approaching the limit.
     */
    public void checkJournalSize(int totalJournalEntries) {
        if (totalJournalEntries >= MAX_JOURNAL_ENTRIES) {
            log.error("Journal entry limit reached: {}/{} — archival required", totalJournalEntries, MAX_JOURNAL_ENTRIES);
            publishWarning(NodeEvent.ResourceKind.JOURNAL_ENTRIES_COUNT,
                    totalJournalEntries, MAX_JOURNAL_ENTRIES,
                    "Journal entry limit reached — archival required");
        } else if (totalJournalEntries >= WARN_JOURNAL_ENTRIES) {
            log.warn("Approaching journal entry limit: {}/{}", totalJournalEntries, MAX_JOURNAL_ENTRIES);
            publishWarning(NodeEvent.ResourceKind.JOURNAL_ENTRIES_COUNT,
                    totalJournalEntries, MAX_JOURNAL_ENTRIES,
                    "Approaching journal entry limit");
        }
    }

    /**
     * Check database file size and warn if approaching the limit.
     */
    public void checkDatabaseSize(long fileSizeBytes) {
        if (fileSizeBytes >= MAX_DATABASE_SIZE_BYTES) {
            log.error("Database size limit reached: {} bytes — maintenance required", fileSizeBytes);
            publishWarning(NodeEvent.ResourceKind.DATABASE_SIZE_BYTES,
                    fileSizeBytes, MAX_DATABASE_SIZE_BYTES,
                    "Database size limit reached");
        } else if (fileSizeBytes >= WARN_DATABASE_SIZE_BYTES) {
            log.warn("Database approaching size limit: {} / {} bytes", fileSizeBytes, MAX_DATABASE_SIZE_BYTES);
            publishWarning(NodeEvent.ResourceKind.DATABASE_SIZE_BYTES,
                    fileSizeBytes, MAX_DATABASE_SIZE_BYTES,
                    "Database approaching size limit");
        }
    }

    private void publishWarning(NodeEvent.ResourceKind kind, long current, long limit, String details) {
        eventBus.publish(new NodeEvent.ResourceLimitWarning(
                eventBus.nextSequence(),
                Instant.now(),
                kind,
                current,
                limit,
                details));
    }

    /**
     * Thrown when a hard resource limit prevents accepting a new operation.
     */
    public static final class ResourceLimitException extends RuntimeException {
        public ResourceLimitException(String message) { super(message); }
    }
}
