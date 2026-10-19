package org.peerlink.core.transfer.multipath;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Multipath Bandwidth Bonding & Work-Stealing Transfer Scheduler.
 *
 * <p>Stripes file chunks across multiple physical or virtual network interfaces
 * simultaneously (e.g. Wi-Fi, Ethernet, P2P Hotspot). Employs dynamic work-stealing
 * so faster lanes pull more chunks, and provides zero-loss chunk rescue if any lane fails.
 */
public final class MultipathTransferScheduler {

    private static final Logger log = LoggerFactory.getLogger(MultipathTransferScheduler.class);

    private final List<MultipathLane> lanes;

    public MultipathTransferScheduler(List<MultipathLane> lanes) {
        if (lanes == null || lanes.isEmpty()) {
            throw new IllegalArgumentException("At least one MultipathLane must be provided");
        }
        this.lanes = List.copyOf(lanes);
    }

    public List<MultipathLane> getLanes() {
        return lanes;
    }

    /**
     * Dispatch totalChunks across all available lanes concurrently using dynamic work-stealing.
     *
     * @param totalChunks total number of chunks to transfer
     * @return CompletableFuture resolving with final transfer telemetry metrics
     */
    public CompletableFuture<MultipathTransferResult> dispatchChunks(int totalChunks) {
        if (totalChunks <= 0) {
            return CompletableFuture.completedFuture(MultipathTransferResult.success(0, lanes.size(), 0));
        }

        long startTime = System.currentTimeMillis();
        CompletableFuture<MultipathTransferResult> overallFuture = new CompletableFuture<>();

        ConcurrentLinkedDeque<Integer> workQueue = new ConcurrentLinkedDeque<>();
        for (int i = 0; i < totalChunks; i++) {
            workQueue.add(i);
        }

        AtomicInteger completedCount = new AtomicInteger(0);
        AtomicInteger inFlightCount = new AtomicInteger(0);
        AtomicBoolean isCompleted = new AtomicBoolean(false);
        Object lock = new Object();

        for (MultipathLane lane : lanes) {
            startLaneWorker(lane, workQueue, inFlightCount, completedCount, totalChunks, startTime, isCompleted, overallFuture, lock);
        }

        return overallFuture;
    }

    private void startLaneWorker(
            MultipathLane lane,
            ConcurrentLinkedDeque<Integer> workQueue,
            AtomicInteger inFlightCount,
            AtomicInteger completedCount,
            int totalChunks,
            long startTime,
            AtomicBoolean isCompleted,
            CompletableFuture<MultipathTransferResult> overallFuture,
            Object lock) {

        CompletableFuture.runAsync(() -> {
            try {
                while (!isCompleted.get()) {
                    if (!lane.isHealthy()) {
                        log.warn("Multipath lane [{}] is marked unhealthy, terminating worker", lane.getLaneId());
                        break;
                    }

                    Integer chunk;
                    synchronized (lock) {
                        chunk = workQueue.pollFirst();
                        if (chunk == null) {
                            if (completedCount.get() >= totalChunks) {
                                if (isCompleted.compareAndSet(false, true)) {
                                    long elapsed = System.currentTimeMillis() - startTime;
                                    int active = (int) lanes.stream().filter(MultipathLane::isHealthy).count();
                                    overallFuture.complete(MultipathTransferResult.success(completedCount.get(), active, elapsed));
                                }
                                lock.notifyAll();
                                break;
                            }

                            if (inFlightCount.get() == 0 && workQueue.isEmpty()) {
                                if (isCompleted.compareAndSet(false, true)) {
                                    long elapsed = System.currentTimeMillis() - startTime;
                                    overallFuture.complete(MultipathTransferResult.failed(
                                            completedCount.get(), 0, elapsed, "No remaining chunks or active workers to complete transfer"));
                                }
                                lock.notifyAll();
                                break;
                            }

                            try {
                                lock.wait(500);
                            } catch (InterruptedException e) {
                                Thread.currentThread().interrupt();
                                break;
                            }
                            continue;
                        } else {
                            inFlightCount.incrementAndGet();
                        }
                    }

                    boolean success = false;
                    try {
                        lane.sendChunk(chunk).join();
                        success = true;
                    } catch (Throwable t) {
                        log.warn("Lane [{}] failed sending chunk {}: {}. Re-queueing chunk for peer lanes.",
                                lane.getLaneId(), chunk, t.getMessage());
                    }

                    synchronized (lock) {
                        inFlightCount.decrementAndGet();
                        if (success) {
                            int finished = completedCount.incrementAndGet();
                            if (finished >= totalChunks) {
                                if (isCompleted.compareAndSet(false, true)) {
                                    long elapsed = System.currentTimeMillis() - startTime;
                                    int active = (int) lanes.stream().filter(MultipathLane::isHealthy).count();
                                    overallFuture.complete(MultipathTransferResult.success(finished, active, elapsed));
                                }
                                lock.notifyAll();
                                break;
                            }
                        } else {
                            // Put chunk back at head of queue for immediate rescue by surviving lanes
                            workQueue.addFirst(chunk);
                            lock.notifyAll();
                            break; // this lane failed, stop this lane's worker
                        }
                    }
                }
            } finally {
                synchronized (lock) {
                    lock.notifyAll();
                    checkLivenessAndFailover(workQueue, completedCount, totalChunks, startTime, isCompleted, overallFuture);
                }
            }
        });
    }

    private void checkLivenessAndFailover(
            ConcurrentLinkedDeque<Integer> workQueue,
            AtomicInteger completedCount,
            int totalChunks,
            long startTime,
            AtomicBoolean isCompleted,
            CompletableFuture<MultipathTransferResult> overallFuture) {

        long healthyLanes = lanes.stream().filter(MultipathLane::isHealthy).count();
        if (healthyLanes == 0 && completedCount.get() < totalChunks) {
            if (isCompleted.compareAndSet(false, true)) {
                long elapsed = System.currentTimeMillis() - startTime;
                overallFuture.complete(MultipathTransferResult.failed(
                        completedCount.get(), 0, elapsed, "All multipath transport lanes disconnected"));
            }
        }
    }
}
