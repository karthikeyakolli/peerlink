package org.peerlink.core.android.discovery;

import org.peerlink.protocol.v1.PeerId;

import java.util.Collections;
import java.util.List;
import java.util.Objects;

/**
 * Record of a discovered peer through any discovery technology.
 */
public final class DiscoveredPeerRecord {
    private final PeerId peerId;
    private final String displayName;
    private final String hostAddress;
    private final int port;
    private final String discoveryTechnology; // e.g. "NSD_MDNS", "WIFI_DIRECT", "WIFI_AWARE", "NEARBY"
    private final List<String> supportedTransports;
    private final long discoveredAtUtcMs;

    public DiscoveredPeerRecord(PeerId peerId,
                                String displayName,
                                String hostAddress,
                                int port,
                                String discoveryTechnology,
                                List<String> supportedTransports) {
        this.peerId = Objects.requireNonNull(peerId, "peerId is required");
        this.displayName = displayName != null ? displayName : peerId.getValue();
        this.hostAddress = Objects.requireNonNull(hostAddress, "hostAddress is required");
        this.port = port;
        this.discoveryTechnology = Objects.requireNonNull(discoveryTechnology, "discoveryTechnology is required");
        this.supportedTransports = supportedTransports != null
                ? Collections.unmodifiableList(supportedTransports)
                : Collections.emptyList();
        this.discoveredAtUtcMs = System.currentTimeMillis();
    }

    public PeerId getPeerId() { return peerId; }
    public String getDisplayName() { return displayName; }
    public String getHostAddress() { return hostAddress; }
    public int getPort() { return port; }
    public String getDiscoveryTechnology() { return discoveryTechnology; }
    public List<String> getSupportedTransports() { return supportedTransports; }
    public long getDiscoveredAtUtcMs() { return discoveredAtUtcMs; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof DiscoveredPeerRecord that)) return false;
        return port == that.port &&
                Objects.equals(peerId, that.peerId) &&
                Objects.equals(hostAddress, that.hostAddress);
    }

    @Override
    public int hashCode() {
        return Objects.hash(peerId, hostAddress, port);
    }
}
