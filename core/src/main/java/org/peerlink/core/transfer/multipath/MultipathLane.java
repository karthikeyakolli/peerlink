package org.peerlink.core.transfer.multipath;

import java.util.concurrent.CompletableFuture;

/**
 * Interface representing a single network transport lane participating
 * in multipath bonded file transfers (e.g. Wi-Fi, Ethernet, P2P Hotspot).
 */
public interface MultipathLane {

    /**
     * Unique identifier for this transport lane.
     */
    String getLaneId();

    /**
     * Indicates whether the lane connection is healthy and able to transmit.
     */
    boolean isHealthy();

    /**
     * Transmit a chunk across this specific network transport lane.
     *
     * @param chunkIndex index of the chunk being sent
     * @return CompletableFuture completing when the chunk is acknowledged
     */
    CompletableFuture<Void> sendChunk(int chunkIndex);
}
