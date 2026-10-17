package org.peerlink.protocol.v1;

import com.google.protobuf.InvalidProtocolBufferException;

public class TransferManifest {
    public static TransferManifest parseFrom(byte[] data) throws InvalidProtocolBufferException {
        return new TransferManifest();
    }

    public byte[] toByteArray() {
        return new byte[0];
    }
}
