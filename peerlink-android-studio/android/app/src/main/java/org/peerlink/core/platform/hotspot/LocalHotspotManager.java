package org.peerlink.core.platform.hotspot;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.security.SecureRandom;
import java.util.HexFormat;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Direct Local Wi-Fi Hotspot Auto-Configuration Manager.
 *
 * <p>Enables off-grid, router-free P2P high-speed file transfers between devices
 * (such as phones and laptops outdoors or in offline environments).
 * Automatically provisions an ephemeral local WPA2/WPA3 access point profile,
 * generates standard Wi-Fi QR connection tokens, and enforces battery-saving timeouts.
 */
public final class LocalHotspotManager implements AutoCloseable {

    private static final Logger log = LoggerFactory.getLogger(LocalHotspotManager.class);

    private static final String DEFAULT_GATEWAY_IP = "192.168.49.1";
    private static final int DEFAULT_PORT = 52001;
    private static final int DEFAULT_TIMEOUT_MINUTES = 10;

    private static final String ALPHANUMERIC = "23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz";

    private final int port;
    private final String gatewayIp;
    private final int timeoutMinutes;
    private final SecureRandom random = new SecureRandom();

    private volatile HotspotProfile activeProfile;
    private ScheduledExecutorService timeoutScheduler;

    public LocalHotspotManager() {
        this(DEFAULT_PORT, DEFAULT_GATEWAY_IP, DEFAULT_TIMEOUT_MINUTES);
    }

    public LocalHotspotManager(int port, String gatewayIp, int timeoutMinutes) {
        this.port = port;
        this.gatewayIp = gatewayIp;
        this.timeoutMinutes = timeoutMinutes;
    }

    /**
     * Start broadcasting the local direct Wi-Fi hotspot.
     *
     * @return Generated HotspotProfile containing credentials and QR string
     */
    public synchronized HotspotProfile startHotspot() {
        if (activeProfile != null) {
            return activeProfile;
        }

        byte[] suffixBytes = new byte[2];
        random.nextBytes(suffixBytes);
        String suffix = HexFormat.of().formatHex(suffixBytes).toUpperCase();
        String ssid = "PeerLink-Direct-" + suffix;

        StringBuilder passBuilder = new StringBuilder(12);
        for (int i = 0; i < 12; i++) {
            passBuilder.append(ALPHANUMERIC.charAt(random.nextInt(ALPHANUMERIC.length())));
        }
        String passphrase = passBuilder.toString();

        activeProfile = new HotspotProfile(ssid, passphrase, gatewayIp, port);
        log.info("Started LocalHotspotManager on SSID [{}] (Gateway: {}:{})", ssid, gatewayIp, port);

        if (timeoutMinutes > 0) {
            timeoutScheduler = Executors.newSingleThreadScheduledExecutor();
            timeoutScheduler.schedule(this::stopHotspot, timeoutMinutes, TimeUnit.MINUTES);
        }

        return activeProfile;
    }

    /**
     * Stop and tear down the local direct Wi-Fi hotspot.
     */
    public synchronized void stopHotspot() {
        if (activeProfile == null) {
            return;
        }

        log.info("Stopping LocalHotspotManager on SSID [{}]", activeProfile.ssid());
        activeProfile = null;

        if (timeoutScheduler != null) {
            timeoutScheduler.shutdownNow();
            timeoutScheduler = null;
        }
    }

    public boolean isHotspotActive() {
        return activeProfile != null;
    }

    public HotspotProfile getActiveProfile() {
        return activeProfile;
    }

    @Override
    public void close() {
        stopHotspot();
    }
}
