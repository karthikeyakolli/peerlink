package org.peerlink.core.transfer.ephemeral;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Manages active ephemeral file sessions, view quotas, and background TTL expiry.
 */
public final class EphemeralSessionRegistry implements AutoCloseable {
    private static final Logger log = LoggerFactory.getLogger(EphemeralSessionRegistry.class);

    public record EphemeralSession(
            String transferId,
            Path filePath,
            EphemeralTransferPolicy policy,
            AtomicInteger viewCount,
            CompletableFuture<Boolean> shredCompletion
    ) {}

    private final ConcurrentHashMap<String, EphemeralSession> activeSessions = new ConcurrentHashMap<>();
    private final ScheduledExecutorService scheduler;

    public EphemeralSessionRegistry() {
        this.scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "peerlink-ephemeral-sentinel");
            t.setDaemon(true);
            return t;
        });
        // Check TTL every 100 milliseconds for fast responsiveness
        this.scheduler.scheduleAtFixedRate(this::checkExpiredTtl, 100, 100, TimeUnit.MILLISECONDS);
    }

    /**
     * Registers an ephemeral transfer session.
     */
    public EphemeralSession registerSession(String transferId, Path filePath, EphemeralTransferPolicy policy) {
        Objects.requireNonNull(transferId, "transferId cannot be null");
        Objects.requireNonNull(filePath, "filePath cannot be null");
        Objects.requireNonNull(policy, "policy cannot be null");

        EphemeralSession session = new EphemeralSession(
                transferId,
                filePath,
                policy,
                new AtomicInteger(0),
                new CompletableFuture<>()
        );

        activeSessions.put(transferId, session);
        log.info("Registered ephemeral session: {} with policy: {}", transferId, policy);
        return session;
    }

    /**
     * Records a view event on the ephemeral file.
     * If the session exceeds allowed views, triggers immediate crypto-shredding.
     *
     * @return true if view was permitted, false if already shredded or expired
     */
    public boolean recordViewAccess(String transferId) {
        EphemeralSession session = activeSessions.get(transferId);
        if (session == null) {
            return false;
        }

        if (session.policy().isExpired()) {
            triggerShred(session, "TTL Expired");
            return false;
        }

        int currentViews = session.viewCount().incrementAndGet();
        log.info("View access #{} on ephemeral session: {}", currentViews, transferId);

        if (session.policy().isBurnAfterRead() && currentViews >= session.policy().getAllowedViews()) {
            triggerShred(session, "Exceeded allowed view count (" + currentViews + ")");
        }

        return true;
    }

    /**
     * Immediately destroys and shreds the ephemeral session and its file.
     */
    public boolean cancelAndShred(String transferId) {
        EphemeralSession session = activeSessions.remove(transferId);
        if (session == null) {
            return false;
        }
        return triggerShred(session, "Manual Cancellation / Force Shred");
    }

    private boolean triggerShred(EphemeralSession session, String reason) {
        activeSessions.remove(session.transferId());
        log.warn("Shredding ephemeral file for session {} - Reason: {}", session.transferId(), reason);
        try {
            boolean wiped = CryptoShredder.shred(session.filePath());
            session.shredCompletion().complete(wiped);
            return wiped;
        } catch (IOException e) {
            log.error("Failed to shred ephemeral file: " + session.filePath(), e);
            session.shredCompletion().completeExceptionally(e);
            return false;
        }
    }

    public void checkExpiredTtl() {
        for (Map.Entry<String, EphemeralSession> entry : activeSessions.entrySet()) {
            EphemeralSession session = entry.getValue();
            if (session.policy().isExpired()) {
                triggerShred(session, "TTL Auto-Expiry reached");
            }
        }
    }

    public int getActiveSessionCount() {
        return activeSessions.size();
    }

    public EphemeralSession getSession(String transferId) {
        return activeSessions.get(transferId);
    }

    @Override
    public void close() {
        scheduler.shutdownNow();
    }
}
