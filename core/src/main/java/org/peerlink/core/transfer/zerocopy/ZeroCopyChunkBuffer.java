package org.peerlink.core.transfer.zerocopy;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.WritableByteChannel;

/**
 * Off-heap direct memory buffer wrapper supporting zero-copy chunk framing and recycling.
 */
public final class ZeroCopyChunkBuffer implements AutoCloseable {

    private final ByteBuffer rawBuffer;
    private final ZeroCopyBufferPool pool;
    private int headerLength = 0;
    private int payloadLength = 0;

    ZeroCopyChunkBuffer(ByteBuffer rawBuffer, ZeroCopyBufferPool pool) {
        this.rawBuffer = rawBuffer;
        this.pool = pool;
    }

    public ByteBuffer rawBuffer() {
        return rawBuffer;
    }

    public int capacity() {
        return rawBuffer.capacity();
    }

    public void writeHeader(byte[] header) {
        rawBuffer.position(0);
        rawBuffer.put(header);
        this.headerLength = header.length;
    }

    public void writePayload(byte[] payload) {
        rawBuffer.position(headerLength);
        rawBuffer.put(payload);
        this.payloadLength = payload.length;
    }

    public void flushTo(WritableByteChannel channel) throws IOException {
        rawBuffer.position(0);
        rawBuffer.limit(headerLength + payloadLength);
        while (rawBuffer.hasRemaining()) {
            channel.write(rawBuffer);
        }
    }

    public void reset() {
        headerLength = 0;
        payloadLength = 0;
        rawBuffer.clear();
    }

    @Override
    public void close() {
        reset();
        if (pool != null) {
            pool.release(this);
        }
    }
}
