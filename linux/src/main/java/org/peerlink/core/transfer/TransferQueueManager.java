package org.peerlink.core.transfer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * Manages transfer queueing, concurrency limits, and offline-peer staging.
 */
public final class TransferQueueManager {
    private static final Logger log = LoggerFactory.getLogger(TransferQueueManager.class);

    public record QueuedTransfer(
            String transferId,
            String operationId,
            String targetPeerId,
            int priority,
            long queuedAtTimestampUtcMs,
            Runnable transferTask
    ) implements Comparable<QueuedTransfer> {
        @Override
        public int compareTo(QueuedTransfer other) {
            // Higher priority first; then earlier timestamp
            int p = Integer.compare(other.priority, this.priority);
            if (p != 0) return p;
            return Long.compare(this.queuedAtTimestampUtcMs, other.queuedAtTimestampUtcMs);
        }
    }

    private final int maxConcurrentTransfers;
    private final PriorityQueue<QueuedTransfer> readyQueue = new PriorityQueue<>();
    private final Map<String, Queue<QueuedTransfer>> offlineQueueByPeer = new ConcurrentHashMap<>();
    private final Set<String> activeTransferIds = Collections.synchronizedSet(new HashSet<>());
    private final Set<String> onlinePeers = Collections.synchronizedSet(new HashSet<>());

    public TransferQueueManager() {
        this(2); // default max 2 concurrent transfers
    }

    public TransferQueueManager(int maxConcurrentTransfers) {
        this.maxConcurrentTransfers = Math.max(1, maxConcurrentTransfers);
    }

    /**
     * Submit a transfer for execution. If the target peer is offline, parks in the offline queue.
     * If concurrency limit is reached, places in ready queue. Otherwise runs immediately.
     */
    public synchronized boolean enqueue(QueuedTransfer transfer) {
        String peerId = transfer.targetPeerId();
        if (!onlinePeers.contains(peerId)) {
            log.info("Target peer {} is offline. Parking transfer {} in offline queue", peerId, transfer.transferId());
            offlineQueueByPeer.computeIfAbsent(peerId, k -> new ConcurrentLinkedQueue<>()).add(transfer);
            return false;
        }

        if (activeTransferIds.size() >= maxConcurrentTransfers) {
            log.info("Concurrency limit reached ({}/{}). Enqueuing transfer {}",
                    activeTransferIds.size(), maxConcurrentTransfers, transfer.transferId());
            readyQueue.add(transfer);
            return false;
        }

        startTransfer(transfer);
        return true;
    }

    private synchronized void startTransfer(QueuedTransfer transfer) {
        activeTransferIds.add(transfer.transferId());
        log.info("Starting active transfer {} (active count: {})", transfer.transferId(), activeTransferIds.size());
        new Thread(() -> {
            try {
                transfer.transferTask().run();
            } finally {
                onTransferFinished(transfer.transferId());
            }
        }, "transfer-worker-" + transfer.transferId()).start();
    }

    /**
     * Notify that an active transfer has finished (completed, failed, or cancelled).
     */
    public synchronized void onTransferFinished(String transferId) {
        activeTransferIds.remove(transferId);
        log.info("Transfer {} finished. Checking queue (active: {})", transferId, activeTransferIds.size());
        dispatchNext();
    }

    private synchronized void dispatchNext() {
        while (activeTransferIds.size() < maxConcurrentTransfers && !readyQueue.isEmpty()) {
            QueuedTransfer next = readyQueue.poll();
            if (next != null) {
                startTransfer(next);
            }
        }
    }

    /**
     * Notify that a peer has come online. Flushes any pending offline transfers for that peer into the ready queue.
     */
    public synchronized void onPeerOnline(String peerId) {
        onlinePeers.add(peerId);
        Queue<QueuedTransfer> offline = offlineQueueByPeer.remove(peerId);
        if (offline != null && !offline.isEmpty()) {
            log.info("Peer {} is now online. Promoting {} parked offline transfers to ready queue", peerId, offline.size());
            readyQueue.addAll(offline);
            dispatchNext();
        }
    }

    /**
     * Notify that a peer has disconnected / gone offline.
     */
    public synchronized void onPeerOffline(String peerId) {
        onlinePeers.remove(peerId);
    }

    public synchronized int getActiveCount() {
        return activeTransferIds.size();
    }

    public synchronized int getReadyQueueSize() {
        return readyQueue.size();
    }

    public synchronized int getOfflineQueueSize(String peerId) {
        Queue<QueuedTransfer> queue = offlineQueueByPeer.get(peerId);
        return queue != null ? queue.size() : 0;
    }
}
