package org.peerlink.core.platform.hotspot;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Objects;

/**
 * Immutable configuration profile for an active direct P2P Wi-Fi Hotspot.
 */
public record HotspotProfile(
        String ssid,
        String passphrase,
        String gatewayIp,
        int listenPort
) {
    public HotspotProfile {
        Objects.requireNonNull(ssid, "ssid must not be null");
        Objects.requireNonNull(passphrase, "passphrase must not be null");
        Objects.requireNonNull(gatewayIp, "gatewayIp must not be null");
        if (listenPort <= 0 || listenPort > 65535) {
            throw new IllegalArgumentException("Invalid port: " + listenPort);
        }
    }

    /**
     * Format as standard Wi-Fi configuration string for QR code generation.
     * Compatible with iOS Camera, Android Wi-Fi QR, and standard bar-code scanners.
     */
    public String toWifiQrPayload() {
        return String.format("WIFI:S:%s;T:WPA;P:%s;;", ssid, passphrase);
    }

    /**
     * Format as a deep-link URI for instant PeerLink app auto-connect.
     */
    public String toPeerLinkConnectionUri() {
        return String.format("peerlink://hotspot?ssid=%s&pass=%s&ip=%s&port=%d",
                URLEncoder.encode(ssid, StandardCharsets.UTF_8),
                URLEncoder.encode(passphrase, StandardCharsets.UTF_8),
                URLEncoder.encode(gatewayIp, StandardCharsets.UTF_8),
                listenPort);
    }
}
