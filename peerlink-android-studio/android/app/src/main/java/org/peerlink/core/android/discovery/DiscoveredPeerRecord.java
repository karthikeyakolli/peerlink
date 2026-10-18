package org.peerlink.core.android.discovery;

import org.peerlink.protocol.v1.PeerId;

import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Record of a discovered peer aggregating multiple transport routes across discovery technologies.
 * Tracks freshness, health, connection state, and candidate routes.
 */
public final class DiscoveredPeerRecord {
    private final PeerId peerId;
    private volatile String displayName;
    private final Set<String> discoveryTechnologies = Collections.synchronizedSet(new LinkedHashSet<>());
    private final List<PeerTransportRoute> availableRoutes = new CopyOnWriteArrayList<>();
    private final long discoveredAtUtcMs;
    private volatile long lastSeenAtUtcMs;
    private volatile PeerConnectionState connectionState = PeerConnectionState.DISCOVERED;

    public DiscoveredPeerRecord(PeerId peerId,
                                String displayName,
                                String hostAddress,
                                int port,
                                String discoveryTechnology,
                                List<String> supportedTransports) {
        this.peerId = Objects.requireNonNull(peerId, "peerId is required");
        this.displayName = displayName != null && !displayName.isBlank() ? displayName : peerId.getValue();
        this.discoveredAtUtcMs = System.currentTimeMillis();
        this.lastSeenAtUtcMs = this.discoveredAtUtcMs;

        if (discoveryTechnology != null) {
            this.discoveryTechnologies.add(discoveryTechnology);
        }

        int priority = calculatePriority(discoveryTechnology);
        PeerTransportRoute initialRoute = new PeerTransportRoute(
                hostAddress, port, discoveryTechnology != null ? discoveryTechnology : "UNKNOWN",
                supportedTransports, priority
        );
        this.availableRoutes.add(initialRoute);
    }

    public static int calculatePriority(String technology) {
        if (technology == null) return 5;
        return switch (technology) {
            case "NSD_MDNS" -> 1;
            case "WIFI_DIRECT" -> 2;
            case "WIFI_AWARE" -> 3;
            case "MANUAL" -> 4;
            default -> 5;
        };
    }

    public PeerId getPeerId() { return peerId; }
    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) {
        if (displayName != null && !displayName.isBlank()) {
            this.displayName = displayName;
        }
    }

    public long getDiscoveredAtUtcMs() { return discoveredAtUtcMs; }
    public long getLastSeenAtUtcMs() { return lastSeenAtUtcMs; }

    public PeerConnectionState getConnectionState() { return connectionState; }
    public void setConnectionState(PeerConnectionState connectionState) {
        this.connectionState = Objects.requireNonNull(connectionState);
    }

    public Set<String> getDiscoveryTechnologies() {
        return Collections.unmodifiableSet(new LinkedHashSet<>(discoveryTechnologies));
    }

    public String getDiscoveryTechnology() {
        return String.join(", ", discoveryTechnologies);
    }

    public List<PeerTransportRoute> getAvailableRoutes() {
        List<PeerTransportRoute> list = new ArrayList<>(availableRoutes);
        list.sort(Comparator.comparingInt(PeerTransportRoute::getPriority));
        return Collections.unmodifiableList(list);
    }

    public PeerTransportRoute getBestRoute() {
        List<PeerTransportRoute> routes = getAvailableRoutes();
        for (PeerTransportRoute r : routes) {
            if (r.isHealthy()) {
                return r;
            }
        }
        return routes.isEmpty() ? null : routes.get(0);
    }

    public String getHostAddress() {
        PeerTransportRoute best = getBestRoute();
        return best != null ? best.getHostAddress() : "127.0.0.1";
    }

    public int getPort() {
        PeerTransportRoute best = getBestRoute();
        return best != null ? best.getPort() : 8765;
    }

    public List<String> getSupportedTransports() {
        Set<String> transports = new LinkedHashSet<>();
        for (PeerTransportRoute r : availableRoutes) {
            transports.addAll(r.getSupportedTransports());
        }
        return new ArrayList<>(transports);
    }

    /**
     * Merges a new or updated route into this peer record.
     */
    public synchronized void addOrMergeRoute(PeerTransportRoute route) {
        this.lastSeenAtUtcMs = System.currentTimeMillis();
        this.discoveryTechnologies.add(route.getDiscoveryTechnology());

        boolean updated = false;
        for (PeerTransportRoute existing : availableRoutes) {
            if (existing.equals(route)) {
                existing.touch();
                updated = true;
                break;
            }
        }
        if (!updated) {
            this.availableRoutes.add(route);
        }
    }

    /**
     * Merges another peer record discovered on a different technology or route.
     */
    public synchronized void mergeFrom(DiscoveredPeerRecord other) {
        if (!this.peerId.equals(other.peerId)) {
            throw new IllegalArgumentException("Cannot merge records with different peerIds: " + peerId + " vs " + other.peerId);
        }
        this.lastSeenAtUtcMs = System.currentTimeMillis();
        if ((this.displayName == null || this.displayName.equals(this.peerId.getValue())) && other.displayName != null) {
            this.displayName = other.displayName;
        }
        this.discoveryTechnologies.addAll(other.discoveryTechnologies);
        for (PeerTransportRoute r : other.availableRoutes) {
            addOrMergeRoute(r);
        }
    }

    /**
     * Prunes routes that have not been seen within maxAgeMs.
     * Returns true if all routes are expired.
     */
    public synchronized boolean pruneExpiredRoutes(long maxAgeMs) {
        long now = System.currentTimeMillis();
        availableRoutes.removeIf(r -> (now - r.getLastSeenAtUtcMs()) > maxAgeMs);
        return availableRoutes.isEmpty() || (now - lastSeenAtUtcMs) > maxAgeMs;
    }

    public boolean isExpired(long maxAgeMs) {
        long now = System.currentTimeMillis();
        return (now - lastSeenAtUtcMs) > maxAgeMs;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("peerId", peerId.getValue());
        map.put("name", displayName);
        map.put("host", getHostAddress());
        map.put("port", getPort());
        map.put("technology", getDiscoveryTechnology());
        map.put("transports", getSupportedTransports());
        map.put("connectionState", connectionState.name());
        map.put("lastSeenMs", lastSeenAtUtcMs);

        List<Map<String, Object>> routeMaps = new ArrayList<>();
        for (PeerTransportRoute r : getAvailableRoutes()) {
            routeMaps.add(r.toMap());
        }
        map.put("routes", routeMaps);
        return map;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof DiscoveredPeerRecord that)) return false;
        return Objects.equals(peerId, that.peerId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(peerId);
    }

    @Override
    public String toString() {
        return "DiscoveredPeerRecord{" +
                "peerId=" + peerId.getValue() +
                ", displayName='" + displayName + '\'' +
                ", technologies=" + discoveryTechnologies +
                ", routes=" + availableRoutes.size() +
                ", state=" + connectionState +
                '}';
    }
}
