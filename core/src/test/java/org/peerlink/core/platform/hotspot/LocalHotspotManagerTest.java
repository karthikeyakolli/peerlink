package org.peerlink.core.platform.hotspot;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Direct Local Wi-Fi Hotspot Auto-Configuration Tests")
class LocalHotspotManagerTest {

    @Test
    @DisplayName("Hotspot profile formats standard Wi-Fi QR code payload (WIFI:S:...;T:WPA;P:...;;)")
    void formatsStandardWifiQrPayload() {
        HotspotProfile profile = new HotspotProfile("PeerLink-Direct-7A9B", "k8F3m9Qx2Z1w", "192.168.49.1", 52001);

        String qrPayload = profile.toWifiQrPayload();
        assertEquals("WIFI:S:PeerLink-Direct-7A9B;T:WPA;P:k8F3m9Qx2Z1w;;", qrPayload);

        String peerlinkUri = profile.toPeerLinkConnectionUri();
        assertTrue(peerlinkUri.startsWith("peerlink://hotspot?"));
        assertTrue(peerlinkUri.contains("ssid=PeerLink-Direct-7A9B"));
        assertTrue(peerlinkUri.contains("port=52001"));
    }

    @Test
    @DisplayName("LocalHotspotManager generates secure random credentials on start")
    void generatesCredentialsOnStart() {
        LocalHotspotManager manager = new LocalHotspotManager();
        assertFalse(manager.isHotspotActive());

        HotspotProfile profile = manager.startHotspot();
        assertTrue(manager.isHotspotActive());
        assertNotNull(profile);
        assertTrue(profile.ssid().startsWith("PeerLink-Direct-"));
        assertTrue(profile.passphrase().length() >= 10);
        assertEquals("192.168.49.1", profile.gatewayIp());
        assertEquals(52001, profile.listenPort());

        // Stop hotspot
        manager.stopHotspot();
        assertFalse(manager.isHotspotActive());
        assertNull(manager.getActiveProfile());
    }

    @Test
    @DisplayName("Custom configuration allows setting specific port and gateway IP")
    void customConfiguration() {
        LocalHotspotManager manager = new LocalHotspotManager(53000, "192.168.137.1", 15);
        HotspotProfile profile = manager.startHotspot();

        assertEquals(53000, profile.listenPort());
        assertEquals("192.168.137.1", profile.gatewayIp());

        manager.stopHotspot();
    }
}
