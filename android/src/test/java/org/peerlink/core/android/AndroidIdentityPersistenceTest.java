package org.peerlink.core.android;

import org.junit.jupiter.api.Test;
import org.peerlink.protocol.v1.PeerId;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;

import static org.junit.jupiter.api.Assertions.*;

class AndroidIdentityPersistenceTest {

    @Test
    void testIdentityGenerationAndSignatureVerification() throws GeneralSecurityException {
        AndroidKeystoreManager.SoftwareKeystoreProvider provider =
                new AndroidKeystoreManager.SoftwareKeystoreProvider(false);
        AndroidKeystoreManager manager = new AndroidKeystoreManager(provider, "test_device_alias");

        PeerId peerId = manager.getPeerId();
        assertNotNull(peerId);
        assertTrue(peerId.getValue().startsWith("android-peer-"));

        byte[] payload = "Critical pairing handshake payload".getBytes(StandardCharsets.UTF_8);
        byte[] signature = manager.sign(payload);
        assertNotNull(signature);
        assertTrue(signature.length > 0);

        boolean valid = manager.verify(payload, signature);
        assertTrue(valid);

        byte[] tampered = "Tampered handshake payload".getBytes(StandardCharsets.UTF_8);
        assertFalse(manager.verify(tampered, signature));
    }

    @Test
    void testIdentityPersistenceAcrossRestart() throws GeneralSecurityException {
        // Shared provider simulates persistent hardware Keystore
        AndroidKeystoreManager.SoftwareKeystoreProvider persistentKeystore =
                new AndroidKeystoreManager.SoftwareKeystoreProvider(true);

        // First startup: initialize identity
        AndroidKeystoreManager firstBoot = new AndroidKeystoreManager(persistentKeystore, "persistent_alias");
        String firstPeerId = firstBoot.getPeerId().getValue();
        byte[] firstPublicKey = firstBoot.getIdentityKeyPair().getPublic().getEncoded();

        // Second startup (simulating application restart): load existing identity
        AndroidKeystoreManager secondBoot = new AndroidKeystoreManager(persistentKeystore, "persistent_alias");
        String secondPeerId = secondBoot.getPeerId().getValue();
        byte[] secondPublicKey = secondBoot.getIdentityKeyPair().getPublic().getEncoded();

        assertEquals(firstPeerId, secondPeerId, "Device Peer ID must remain invariant across restarts");
        assertArrayEquals(firstPublicKey, secondPublicKey, "Public key must remain identical across restarts");

        // Verify signature created by first boot can be verified by second boot
        byte[] data = "Data signed across boots".getBytes(StandardCharsets.UTF_8);
        byte[] sig = firstBoot.sign(data);
        assertTrue(secondBoot.verify(data, sig));
    }
}
