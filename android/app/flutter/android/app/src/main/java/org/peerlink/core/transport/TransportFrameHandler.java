package org.peerlink.core.transport;

import org.peerlink.protocol.v1.TransportFrame;

@FunctionalInterface
public interface TransportFrameHandler {
    void handleFrame(TransportConnection connection, TransportFrame frame);
}
