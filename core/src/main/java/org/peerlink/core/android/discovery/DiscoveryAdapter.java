package org.peerlink.core.android.discovery;

import org.peerlink.protocol.v1.PeerId;

/**
 * Common interface for platform-specific and generic discovery mechanisms.
 * Keeps PeerLink independent of Google-specific services.
 */
public interface DiscoveryAdapter {

    interface DiscoveryCallback {
        void onPeerFound(DiscoveredPeerRecord peer);
        void onPeerLost(PeerId peerId);
        void onDiscoveryError(String technology, String errorMessage);
    }

    String getTechnologyName();
    boolean isAvailable();
    void startDiscovery(DiscoveryCallback callback);
    void stopDiscovery();
    void startAdvertising(PeerId localPeerId, String displayName, int port);
    void stopAdvertising();
}
