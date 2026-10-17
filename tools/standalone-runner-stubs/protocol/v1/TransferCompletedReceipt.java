package org.peerlink.protocol.v1;

import com.google.protobuf.InvalidProtocolBufferException;

public class TransferCompletedReceipt {
    private final byte[] bytes;
    private final long totalBytes;

    public TransferCompletedReceipt(byte[] bytes, long totalBytes) {
        this.bytes = bytes;
        this.totalBytes = totalBytes;
    }

    public static TransferCompletedReceipt parseFrom(byte[] data) throws InvalidProtocolBufferException {
        return new TransferCompletedReceipt(data, data != null ? data.length : 0);
    }

    public byte[] toByteArray() {
        return bytes != null ? bytes : new byte[0];
    }

    public long getTotalBytesTransferred() {
        return totalBytes;
    }
}
