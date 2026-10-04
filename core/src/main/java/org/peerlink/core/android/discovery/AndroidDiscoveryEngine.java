package org.peerlink.core.android.discovery;

import org.peerlink.protocol.v1.PeerId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Discovery engine coordinating multiple platform discovery adapters
 * (NSD/mDNS, Wi-Fi Direct, Wi-Fi Aware, Nearby RF).
 * Aggregates and deduplicates discovered peers across network technologies.
 */
public class AndroidDiscoveryEngine implements DiscoveryAdapter.DiscoveryCallback {
    private static final Logger log = LoggerFactory.getLogger(AndroidDiscoveryEngine.class);

    public interface EngineListener {
        void onPeerDiscovered(DiscoveredPeerRecord peer);
        void onPeerLost(PeerId peerId);
    }

    private final List<DiscoveryAdapter> adapters = new CopyOnWriteArrayList<>();
    private final List<EngineListener> listeners = new CopyOnWriteArrayList<>();
    private final ConcurrentMap<PeerId, DiscoveredPeerRecord> activePeers = new ConcurrentHashMap<>();
    private volatile boolean isRunning = false;

    public AndroidDiscoveryEngine(List<DiscoveryAdapter> adapters) {
        if (adapters != null) {
            this.adapters.addAll(adapters);
        }
    }

    public void addAdapter(DiscoveryAdapter adapter) {
        this.adapters.add(Objects.requireNonNull(adapter));
        if (isRunning && adapter.isAvailable()) {
            adapter.startDiscovery(this);
        }
    }

    public void addListener(EngineListener listener) {
        this.listeners.add(Objects.requireNonNull(listener));
    }

    public void removeListener(EngineListener listener) {
        this.listeners.remove(listener);
    }

    public synchronized void startAll() {
        if (isRunning) return;
        isRunning = true;
        log.info("Starting AndroidDiscoveryEngine with {} adapters", adapters.size());
        for (DiscoveryAdapter adapter : adapters) {
            if (adapter.isAvailable()) {
                try {
                    adapter.startDiscovery(this);
                } catch (Exception e) {
                    log.error("Failed to start discovery adapter: " + adapter.getTechnologyName(), e);
                }
            } else {
                log.info("Adapter {} is unavailable on this device/network", adapter.getTechnologyName());
            }
        }
    }

    public synchronized void stopAll() {
        if (!isRunning) return;
        isRunning = false;
        log.info("Stopping AndroidDiscoveryEngine");
        for (DiscoveryAdapter adapter : adapters) {
            try {
                adapter.stopDiscovery();
                adapter.stopAdvertising();
            } catch (Exception e) {
                log.error("Error stopping adapter: " + adapter.getTechnologyName(), e);
            }
        }
        activePeers.clear();
    }

    public synchronized void startAdvertisingAll(PeerId localPeerId, String displayName, int port) {
        for (DiscoveryAdapter adapter : adapters) {
            if (adapter.isAvailable()) {
                try {
                    adapter.startAdvertising(localPeerId, displayName, port);
                } catch (Exception e) {
                    log.error("Failed to start advertising on: " + adapter.getTechnologyName(), e);
                }
            }
        }
    }

    @Override
    public void onPeerFound(DiscoveredPeerRecord peer) {
        activePeers.put(peer.getPeerId(), peer);
        log.info("Peer discovered via {}: {} ({}:{})",
                peer.getDiscoveryTechnology(), peer.getDisplayName(), peer.getHostAddress(), peer.getPort());
        for (EngineListener listener : listeners) {
            try {
                listener.onPeerDiscovered(peer);
            } catch (Exception e) {
                log.error("Error notifying listener of discovered peer", e);
            }
        }
    }

    @Override
    public void onPeerLost(PeerId peerId) {
        DiscoveredPeerRecord removed = activePeers.remove(peerId);
        if (removed != null) {
            log.info("Peer lost: {}", peerId.getValue());
            for (EngineListener listener : listeners) {
                try {
                    listener.onPeerLost(peerId);
                } catch (Exception e) {
                    log.error("Error notifying listener of lost peer", e);
                }
            }
        }
    }

    @Override
    public void onDiscoveryError(String technology, String errorMessage) {
        log.warn("Discovery error on {}: {}", technology, errorMessage);
    }

    public Map<PeerId, DiscoveredPeerRecord> getActivePeers() {
        return Collections.unmodifiableMap(activePeers);
    }

    public boolean isRunning() {
        return isRunning;
    }
}
