package org.peerlink.core.android.discovery;

import org.peerlink.protocol.v1.PeerId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Wi-Fi Aware (NAN - Neighbor Awareness Networking) discovery adapter.
 * Provides ultra-low power local discovery without requiring network association.
 */
public class WifiAwareDiscoveryAdapter implements DiscoveryAdapter {
    private static final Logger log = LoggerFactory.getLogger(WifiAwareDiscoveryAdapter.class);

    private final boolean available;
    private final AtomicBoolean discovering = new AtomicBoolean(false);
    private final AtomicBoolean advertising = new AtomicBoolean(false);
    private DiscoveryCallback activeCallback;

    public WifiAwareDiscoveryAdapter(boolean available) {
        this.available = available;
    }

    @Override
    public String getTechnologyName() {
        return "WIFI_AWARE";
    }

    @Override
    public boolean isAvailable() {
        return available;
    }

    @Override
    public synchronized void startDiscovery(DiscoveryCallback callback) {
        if (!available) {
            callback.onDiscoveryError(getTechnologyName(), "Wi-Fi Aware (NAN) hardware not available");
            return;
        }
        this.activeCallback = Objects.requireNonNull(callback);
        this.discovering.set(true);
        log.info("Started Wi-Fi Aware NAN discovery session");
    }

    @Override
    public synchronized void stopDiscovery() {
        this.discovering.set(false);
        this.activeCallback = null;
        log.info("Stopped Wi-Fi Aware discovery");
    }

    @Override
    public synchronized void startAdvertising(PeerId localPeerId, String displayName, int port) {
        if (!available) return;
        this.advertising.set(true);
        log.info("Started Wi-Fi Aware publish session for {}", localPeerId.getValue());
    }

    @Override
    public synchronized void stopAdvertising() {
        this.advertising.set(false);
        log.info("Stopped Wi-Fi Aware publish session");
    }

    public void notifyPeerDiscovered(PeerId peerId, String name, String host, int port, List<String> transports) {
        if (discovering.get() && activeCallback != null) {
            activeCallback.onPeerFound(new DiscoveredPeerRecord(
                    peerId, name, host, port, getTechnologyName(), transports
            ));
        }
    }

    public void notifyPeerLost(PeerId peerId) {
        if (discovering.get() && activeCallback != null) {
            activeCallback.onPeerLost(peerId);
        }
    }

    public boolean isDiscovering() { return discovering.get(); }
    public boolean isAdvertising() { return advertising.get(); }
}
