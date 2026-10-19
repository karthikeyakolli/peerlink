package org.peerlink.core.transfer.multipath;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Multi-Path Bandwidth Bonding & Striping Tests")
class MultipathTransferSchedulerTest {

    @Test
    @DisplayName("Scheduler stripes chunks across multiple lanes concurrently")
    void stripesChunksAcrossMultipleLanes() throws Exception {
        int totalChunks = 50;
        int laneCount = 3;

        Map<String, AtomicInteger> chunksPerLane = new ConcurrentHashMap<>();
        List<MultipathLane> lanes = new ArrayList<>();

        for (int i = 1; i <= laneCount; i++) {
            String laneId = "lane-" + i;
            chunksPerLane.put(laneId, new AtomicInteger(0));
            lanes.add(new MockMultipathLane(laneId, 5, false, () -> {
                chunksPerLane.get(laneId).incrementAndGet();
            }));
        }

        MultipathTransferScheduler scheduler = new MultipathTransferScheduler(lanes);
        CompletableFuture<MultipathTransferResult> future = scheduler.dispatchChunks(totalChunks);

        MultipathTransferResult result = future.get(5, TimeUnit.SECONDS);

        assertTrue(result.isSuccess());
        assertEquals(totalChunks, result.completedChunks());

        // Assert all 3 lanes actively processed chunks
        for (int i = 1; i <= laneCount; i++) {
            String laneId = "lane-" + i;
            int count = chunksPerLane.get(laneId).get();
            assertTrue(count > 5, "Lane " + laneId + " should have processed chunks, got: " + count);
        }
    }

    @Test
    @DisplayName("Work-stealing balances chunks according to lane throughput")
    void balancesAccordingToThroughput() throws Exception {
        int totalChunks = 60;

        AtomicInteger fastCount = new AtomicInteger(0);
        AtomicInteger slowCount = new AtomicInteger(0);

        // Fast lane (1 ms latency) vs Slow lane (30 ms latency)
        MultipathLane fastLane = new MockMultipathLane("fast-lane", 1, false, fastCount::incrementAndGet);
        MultipathLane slowLane = new MockMultipathLane("slow-lane", 30, false, slowCount::incrementAndGet);

        MultipathTransferScheduler scheduler = new MultipathTransferScheduler(List.of(fastLane, slowLane));
        MultipathTransferResult result = scheduler.dispatchChunks(totalChunks).get(5, TimeUnit.SECONDS);

        assertTrue(result.isSuccess());
        assertEquals(totalChunks, result.completedChunks());

        // Fast lane should have handled significantly more chunks than slow lane
        assertTrue(fastCount.get() >= slowCount.get() * 2,
                "Fast lane (" + fastCount.get() + ") should process substantially more than slow lane (" + slowCount.get() + ")");
    }

    @Test
    @DisplayName("Mid-transfer lane failure triggers seamless chunk rescue and re-assignment")
    void midTransferLaneFailureRescue() throws Exception {
        int totalChunks = 40;

        AtomicInteger lane1Count = new AtomicInteger(0);
        AtomicInteger lane2Count = new AtomicInteger(0);
        AtomicBoolean lane2Failed = new AtomicBoolean(false);

        MultipathLane lane1 = new MockMultipathLane("lane-1", 5, false, lane1Count::incrementAndGet);

        // Lane 2 fails after sending 5 chunks
        MultipathLane lane2 = new MultipathLane() {
            @Override
            public String getLaneId() {
                return "lane-2";
            }

            @Override
            public boolean isHealthy() {
                return !lane2Failed.get();
            }

            @Override
            public CompletableFuture<Void> sendChunk(int chunkIndex) {
                if (lane2Count.incrementAndGet() >= 6) {
                    lane2Failed.set(true);
                    CompletableFuture<Void> failed = new CompletableFuture<>();
                    failed.completeExceptionally(new IOException("Wi-Fi interface link down"));
                    return failed;
                }
                return CompletableFuture.runAsync(() -> {
                    try { Thread.sleep(5); } catch (InterruptedException ignored) {}
                });
            }
        };

        MultipathTransferScheduler scheduler = new MultipathTransferScheduler(List.of(lane1, lane2));
        MultipathTransferResult result = scheduler.dispatchChunks(totalChunks).get(5, TimeUnit.SECONDS);

        assertTrue(result.isSuccess(), "Transfer should succeed despite lane-2 failure");
        assertEquals(totalChunks, result.completedChunks(), "All 40 chunks must be delivered");
        assertTrue(lane2Failed.get(), "Lane 2 must have failed");
        assertTrue(lane1Count.get() >= 30, "Lane 1 should have taken over and delivered remaining chunks");
    }

    @Test
    @DisplayName("Requeued chunk is rescued even if peer worker found queue temporarily empty")
    void requeuedChunkRescuedWhenPeerWorkerIdle() throws Exception {
        int totalChunks = 2;
        AtomicInteger fastCount = new AtomicInteger(0);
        AtomicInteger slowCount = new AtomicInteger(0);
        AtomicBoolean slowFailed = new AtomicBoolean(false);

        // Fast lane finishes chunk 0 in 5ms. At 5ms, chunk 1 is in-flight on slow lane, so workQueue is empty!
        MultipathLane fastLane = new MockMultipathLane("fast-lane", 5, false, fastCount::incrementAndGet);

        // Slow lane takes 50ms, then fails and requeues chunk 1!
        MultipathLane slowLane = new MultipathLane() {
            @Override
            public String getLaneId() {
                return "slow-lane";
            }

            @Override
            public boolean isHealthy() {
                return !slowFailed.get();
            }

            @Override
            public CompletableFuture<Void> sendChunk(int chunkIndex) {
                slowCount.incrementAndGet();
                CompletableFuture<Void> f = new CompletableFuture<>();
                CompletableFuture.runAsync(() -> {
                    try { Thread.sleep(60); } catch (InterruptedException ignored) {}
                    slowFailed.set(true);
                    f.completeExceptionally(new IOException("Interface failure"));
                });
                return f;
            }
        };

        MultipathTransferScheduler scheduler = new MultipathTransferScheduler(List.of(fastLane, slowLane));
        // Must complete within 5 seconds without hanging!
        MultipathTransferResult result = scheduler.dispatchChunks(totalChunks).get(3, TimeUnit.SECONDS);

        assertTrue(result.isSuccess(), "Transfer must succeed by rescuing chunk 1 via fast-lane");
        assertEquals(totalChunks, result.completedChunks());
        assertEquals(2, fastCount.get(), "Fast lane must have processed both chunk 0 and the rescued chunk 1");
    }

    @Test
    @DisplayName("When all lanes fail, future completes with failure immediately without hanging")
    void allLanesFailTerminatesWithoutHanging() throws Exception {
        MultipathLane lane1 = new MockMultipathLane("lane-1", 10, true, null);
        MultipathLane lane2 = new MockMultipathLane("lane-2", 10, true, null);

        MultipathTransferScheduler scheduler = new MultipathTransferScheduler(List.of(lane1, lane2));
        MultipathTransferResult result = scheduler.dispatchChunks(10).get(3, TimeUnit.SECONDS);

        assertFalse(result.isSuccess(), "Transfer should fail when all lanes are unhealthy");
        assertTrue(result.failureReason().contains("disconnected") || result.failureReason().contains("No remaining chunks"));
    }

    private static class MockMultipathLane implements MultipathLane {
        private final String laneId;
        private final int simulatedDelayMs;
        private final boolean fail;
        private final Runnable onChunkSent;

        MockMultipathLane(String laneId, int simulatedDelayMs, boolean fail, Runnable onChunkSent) {
            this.laneId = laneId;
            this.simulatedDelayMs = simulatedDelayMs;
            this.fail = fail;
            this.onChunkSent = onChunkSent;
        }

        @Override
        public String getLaneId() {
            return laneId;
        }

        @Override
        public boolean isHealthy() {
            return !fail;
        }

        @Override
        public CompletableFuture<Void> sendChunk(int chunkIndex) {
            if (fail) {
                CompletableFuture<Void> future = new CompletableFuture<>();
                future.completeExceptionally(new IOException("Simulated network link down"));
                return future;
            }
            return CompletableFuture.runAsync(() -> {
                try {
                    Thread.sleep(simulatedDelayMs);
                } catch (InterruptedException ignored) {}
                if (onChunkSent != null) {
                    onChunkSent.run();
                }
            });
        }
    }
}
