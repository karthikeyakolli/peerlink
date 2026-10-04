package org.peerlink.core.diagnostics;

import java.util.concurrent.atomic.AtomicLong;

public final class DiagnosticsCollector {
    private final AtomicLong operationsExecuted = new AtomicLong(0);
    private final AtomicLong bytesTransferred = new AtomicLong(0);
    private final AtomicLong errorsEncountered = new AtomicLong(0);

    public void recordOperation() { operationsExecuted.incrementAndGet(); }
    public void recordBytes(long bytes) { bytesTransferred.addAndGet(bytes); }
    public void recordError() { errorsEncountered.incrementAndGet(); }

    public long getOperationsExecuted() { return operationsExecuted.get(); }
    public long getBytesTransferred() { return bytesTransferred.get(); }
    public long getErrorsEncountered() { return errorsEncountered.get(); }
}
