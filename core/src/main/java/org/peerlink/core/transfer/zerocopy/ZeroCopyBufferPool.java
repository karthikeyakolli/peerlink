package org.peerlink.core.transfer.zerocopy;

import java.nio.ByteBuffer;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * High-performance off-heap direct buffer pool for hardware-accelerated zero-copy transfers.
 * Avoids heap byte-array allocation churn and garbage collection pauses during multi-gigabyte transfers.
 */
public final class ZeroCopyBufferPool {

    private final int maxCapacity;
    private final int bufferSize;
    private final ConcurrentLinkedQueue<ZeroCopyChunkBuffer> availableBuffers = new ConcurrentLinkedQueue<>();

    public ZeroCopyBufferPool(int maxCapacity, int bufferSize) {
        if (maxCapacity <= 0 || bufferSize <= 0) {
            throw new IllegalArgumentException("Capacity and buffer size must be strictly positive");
        }
        this.maxCapacity = maxCapacity;
        this.bufferSize = bufferSize;
    }

    /**
     * Acquire a direct off-heap buffer from the pool, or allocate a new one if empty.
     */
    public ZeroCopyChunkBuffer acquire() {
        ZeroCopyChunkBuffer buffer = availableBuffers.poll();
        if (buffer != null) {
            return buffer;
        }
        ByteBuffer directBuffer = ByteBuffer.allocateDirect(bufferSize);
        return new ZeroCopyChunkBuffer(directBuffer, this);
    }

    /**
     * Return buffer to the pool for reuse.
     */
    void release(ZeroCopyChunkBuffer buffer) {
        if (availableBuffers.size() < maxCapacity) {
            availableBuffers.offer(buffer);
        }
    }

    public int getAvailableCount() {
        return availableBuffers.size();
    }

    public int getBufferSize() {
        return bufferSize;
    }
}
