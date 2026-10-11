package org.peerlink.core.chaos;

import org.peerlink.protocol.v1.TransferChunk;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

/**
 * Programmable network fault injector for chunk and packet transmission chaos.
 */
public final class ChaosNetworkFaultInjector {

    private final Random random;
    private volatile double dropProbability = 0.0;
    private volatile double duplicateProbability = 0.0;
    private volatile boolean reorderChunks = false;
    private volatile long latencyMs = 0;
    private volatile long disconnectAfterChunks = -1;
    private volatile long chunksProcessed = 0;
    private volatile boolean disconnected = false;

    public ChaosNetworkFaultInjector() {
        this(987654321L);
    }

    public ChaosNetworkFaultInjector(long seed) {
        this.random = new Random(seed);
    }

    public void setDropProbability(double dropProbability) {
        this.dropProbability = dropProbability;
    }

    public void setDuplicateProbability(double duplicateProbability) {
        this.duplicateProbability = duplicateProbability;
    }

    public void setReorderChunks(boolean reorderChunks) {
        this.reorderChunks = reorderChunks;
    }

    public void setLatencyMs(long latencyMs) {
        this.latencyMs = latencyMs;
    }

    public void setDisconnectAfterChunks(long disconnectAfterChunks) {
        this.disconnectAfterChunks = disconnectAfterChunks;
    }

    public boolean isDisconnected() {
        return disconnected;
    }

    public void reconnect() {
        this.disconnected = false;
    }

    /**
     * Intercept and filter or transform a list of chunks before sending.
     */
    public List<TransferChunk> processOutgoingChunks(List<TransferChunk> incoming) {
        if (reorderChunks && incoming.size() > 1) {
            List<TransferChunk> shuffled = new ArrayList<>(incoming);
            Collections.shuffle(shuffled, random);
            return processSequence(shuffled);
        }
        return processSequence(incoming);
    }

    private List<TransferChunk> processSequence(List<TransferChunk> chunks) {
        List<TransferChunk> result = new ArrayList<>();
        for (TransferChunk chunk : chunks) {
            if (disconnected) {
                break;
            }

            chunksProcessed++;
            if (disconnectAfterChunks > 0 && chunksProcessed >= disconnectAfterChunks) {
                disconnected = true;
                break;
            }

            if (dropProbability > 0 && random.nextDouble() < dropProbability) {
                // Drop this chunk
                continue;
            }

            if (latencyMs > 0) {
                try {
                    Thread.sleep(latencyMs);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }

            result.add(chunk);

            if (duplicateProbability > 0 && random.nextDouble() < duplicateProbability) {
                // Duplicate chunk
                result.add(chunk);
            }
        }
        return result;
    }
}
