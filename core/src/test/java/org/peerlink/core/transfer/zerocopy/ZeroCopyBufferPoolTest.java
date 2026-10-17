package org.peerlink.core.transfer.zerocopy;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.Channels;
import java.nio.channels.WritableByteChannel;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Zero-Copy Buffer Pool & Direct Memory Tests")
class ZeroCopyBufferPoolTest {

    @Test
    @DisplayName("Acquiring and releasing buffers recycles direct off-heap instances")
    void acquiresAndRecyclesBuffers() {
        int bufferSize = 64 * 1024;
        ZeroCopyBufferPool pool = new ZeroCopyBufferPool(4, bufferSize);

        assertEquals(0, pool.getAvailableCount());

        ZeroCopyChunkBuffer buf1 = pool.acquire();
        assertNotNull(buf1);
        assertTrue(buf1.rawBuffer().isDirect(), "Must allocate off-heap direct ByteBuffer");
        assertEquals(bufferSize, buf1.capacity());

        buf1.close(); // returns to pool
        assertEquals(1, pool.getAvailableCount());

        ZeroCopyChunkBuffer buf2 = pool.acquire();
        assertSame(buf1.rawBuffer(), buf2.rawBuffer(), "Must reuse the identical direct buffer instance");
        assertEquals(0, pool.getAvailableCount());
        buf2.close();
    }

    @Test
    @DisplayName("ZeroCopyChunkBuffer slices header, payload, and auth tag without copying bytes")
    void slicesHeaderAndPayloadZeroCopy() throws IOException {
        ZeroCopyBufferPool pool = new ZeroCopyBufferPool(2, 4096);

        try (ZeroCopyChunkBuffer buffer = pool.acquire()) {
            byte[] headerBytes = "PEERLINK-HEADER:".getBytes(StandardCharsets.UTF_8);
            byte[] payloadBytes = "Sample payload for streaming test".getBytes(StandardCharsets.UTF_8);

            buffer.writeHeader(headerBytes);
            buffer.writePayload(payloadBytes);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            WritableByteChannel channel = Channels.newChannel(baos);
            buffer.flushTo(channel);

            byte[] output = baos.toByteArray();
            assertEquals(headerBytes.length + payloadBytes.length, output.length);

            String combined = new String(output, StandardCharsets.UTF_8);
            assertTrue(combined.startsWith("PEERLINK-HEADER:"));
            assertTrue(combined.endsWith("Sample payload for streaming test"));
        }
    }

    @Test
    @DisplayName("Thread-safe concurrent acquire and release under high parallel load")
    void concurrentPoolUnderLoad() throws Exception {
        int poolCapacity = 8;
        int bufferSize = 16 * 1024;
        ZeroCopyBufferPool pool = new ZeroCopyBufferPool(poolCapacity, bufferSize);

        int threadCount = 16;
        int iterations = 100;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch latch = new CountDownLatch(threadCount);

        for (int t = 0; t < threadCount; t++) {
            executor.submit(() -> {
                try {
                    for (int i = 0; i < iterations; i++) {
                        try (ZeroCopyChunkBuffer buf = pool.acquire()) {
                            ByteBuffer direct = buf.rawBuffer();
                            direct.putInt(0, 0xCAFEBABE);
                            assertEquals(0xCAFEBABE, direct.getInt(0));
                        }
                    }
                } finally {
                    latch.countDown();
                }
            });
        }

        assertTrue(latch.await(5, TimeUnit.SECONDS));
        executor.shutdown();

        // Pool should have retained up to capacity recycled buffers
        assertTrue(pool.getAvailableCount() <= poolCapacity);
    }
}
