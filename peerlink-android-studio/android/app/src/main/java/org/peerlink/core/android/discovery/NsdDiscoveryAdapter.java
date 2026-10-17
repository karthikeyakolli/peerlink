package org.peerlink.core.android.discovery;

import org.peerlink.protocol.v1.PeerId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Android Network Service Discovery (NSD) mDNS adapter (_peerlink._tcp).
 * Standard open LAN service discovery without cloud dependencies.
 */
public class NsdDiscoveryAdapter implements DiscoveryAdapter {
    private static final Logger log = LoggerFactory.getLogger(NsdDiscoveryAdapter.class);
    public static final String SERVICE_TYPE = "_peerlink._tcp";

    private final boolean available;
    private final AtomicBoolean discovering = new AtomicBoolean(false);
    private final AtomicBoolean advertising = new AtomicBoolean(false);
    private DiscoveryCallback activeCallback;

    public NsdDiscoveryAdapter(boolean available) {
        this.available = available;
    }

    @Override
    public String getTechnologyName() {
        return "NSD_MDNS";
    }

    @Override
    public boolean isAvailable() {
        return available;
    }

    @Override
    public synchronized void startDiscovery(DiscoveryCallback callback) {
        if (!available) {
            callback.onDiscoveryError(getTechnologyName(), "NSD / mDNS is not supported on this network interface");
            return;
        }
        this.activeCallback = Objects.requireNonNull(callback);
        this.discovering.set(true);
        log.info("Started NSD / mDNS discovery on service type {}", SERVICE_TYPE);
    }

    @Override
    public synchronized void stopDiscovery() {
        this.discovering.set(false);
        this.activeCallback = null;
        log.info("Stopped NSD / mDNS discovery");
    }

    @Override
    public synchronized void startAdvertising(PeerId localPeerId, String displayName, int port) {
        if (!available) {
            log.warn("Cannot start NSD advertising: service unavailable");
            return;
        }
        this.advertising.set(true);
        log.info("Advertising PeerLink NSD service: {} ({}) on port {}", localPeerId.getValue(), displayName, port);
    }

    @Override
    public synchronized void stopAdvertising() {
        this.advertising.set(false);
        log.info("Stopped NSD advertising");
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
