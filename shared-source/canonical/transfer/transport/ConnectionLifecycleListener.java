package org.peerlink.core.transport;

public interface ConnectionLifecycleListener {
    void onStateChanged(TransportConnection connection, ConnectionState oldState, ConnectionState newState);
    void onError(TransportConnection connection, Throwable throwable);
}
