package org.peerlink.core.android.discovery;

import java.util.*;

/**
 * Concrete network route to a discovered peer.
 * A single peer may have multiple routes (e.g. Wi-Fi LAN IP + Wi-Fi Direct P2P IP).
 */
public final class PeerTransportRoute {
    private final String hostAddress;
    private final int port;
    private final String discoveryTechnology; // "NSD_MDNS", "WIFI_DIRECT", "WIFI_AWARE", "MANUAL"
    private final List<String> supportedTransports;
    private final int priority;
    private volatile long lastSeenAtUtcMs;
    private volatile boolean isHealthy;
    private volatile int failureCount;

    public PeerTransportRoute(String hostAddress,
                              int port,
                              String discoveryTechnology,
                              List<String> supportedTransports,
                              int priority) {
        this.hostAddress = Objects.requireNonNull(hostAddress, "hostAddress is required");
        this.port = port;
        this.discoveryTechnology = Objects.requireNonNull(discoveryTechnology, "discoveryTechnology is required");
        this.supportedTransports = supportedTransports != null
                ? Collections.unmodifiableList(new ArrayList<>(supportedTransports))
                : Collections.emptyList();
        this.priority = priority;
        this.lastSeenAtUtcMs = System.currentTimeMillis();
        this.isHealthy = true;
        this.failureCount = 0;
    }

    public String getHostAddress() { return hostAddress; }
    public int getPort() { return port; }
    public String getDiscoveryTechnology() { return discoveryTechnology; }
    public List<String> getSupportedTransports() { return supportedTransports; }
    public int getPriority() { return priority; }
    public long getLastSeenAtUtcMs() { return lastSeenAtUtcMs; }
    public boolean isHealthy() { return isHealthy; }
    public int getFailureCount() { return failureCount; }

    public void touch() {
        this.lastSeenAtUtcMs = System.currentTimeMillis();
        this.isHealthy = true;
        this.failureCount = 0;
    }

    public void markSuccess() {
        this.lastSeenAtUtcMs = System.currentTimeMillis();
        this.isHealthy = true;
        this.failureCount = 0;
    }

    public void markFailure() {
        this.failureCount++;
        if (this.failureCount >= 2) {
            this.isHealthy = false;
        }
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("host", hostAddress);
        map.put("port", port);
        map.put("technology", discoveryTechnology);
        map.put("transports", supportedTransports);
        map.put("priority", priority);
        map.put("lastSeenMs", lastSeenAtUtcMs);
        map.put("isHealthy", isHealthy);
        return map;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof PeerTransportRoute that)) return false;
        return port == that.port &&
                Objects.equals(hostAddress, that.hostAddress) &&
                Objects.equals(discoveryTechnology, that.discoveryTechnology);
    }

    @Override
    public int hashCode() {
        return Objects.hash(hostAddress, port, discoveryTechnology);
    }

    @Override
    public String toString() {
        return discoveryTechnology + "://" + hostAddress + ":" + port + " [prio=" + priority + ", healthy=" + isHealthy + "]";
    }
}
