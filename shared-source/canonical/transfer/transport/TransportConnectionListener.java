package org.peerlink.core.transport;

@FunctionalInterface
public interface TransportConnectionListener {
    void onConnectionAccepted(TransportConnection connection);
}
