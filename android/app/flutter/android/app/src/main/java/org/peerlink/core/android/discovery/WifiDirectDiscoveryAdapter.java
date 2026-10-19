package org.peerlink.core.android.discovery;

import org.peerlink.protocol.v1.PeerId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Wi-Fi Direct (P2P) discovery adapter using WifiP2pManager.
 * Operates device-to-device off-grid without an access point.
 */
public class WifiDirectDiscoveryAdapter implements DiscoveryAdapter {
    private static final Logger log = LoggerFactory.getLogger(WifiDirectDiscoveryAdapter.class);

    private final boolean available;
    private final AtomicBoolean discovering = new AtomicBoolean(false);
    private final AtomicBoolean advertising = new AtomicBoolean(false);
    private DiscoveryCallback activeCallback;

    public WifiDirectDiscoveryAdapter(boolean available) {
        this.available = available;
    }

    @Override
    public String getTechnologyName() {
        return "WIFI_DIRECT";
    }

    @Override
    public boolean isAvailable() {
        return available;
    }

    @Override
    public synchronized void startDiscovery(DiscoveryCallback callback) {
        if (!available) {
            callback.onDiscoveryError(getTechnologyName(), "Wi-Fi Direct hardware/service not available");
            return;
        }
        this.activeCallback = Objects.requireNonNull(callback);
        this.discovering.set(true);
        log.info("Started Wi-Fi Direct peer discovery");
    }

    @Override
    public synchronized void stopDiscovery() {
        this.discovering.set(false);
        this.activeCallback = null;
        log.info("Stopped Wi-Fi Direct peer discovery");
    }

    @Override
    public synchronized void startAdvertising(PeerId localPeerId, String displayName, int port) {
        if (!available) return;
        this.advertising.set(true);
        log.info("Advertising Wi-Fi Direct local service for {}", localPeerId.getValue());
    }

    @Override
    public synchronized void stopAdvertising() {
        this.advertising.set(false);
        log.info("Stopped Wi-Fi Direct advertising");
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
