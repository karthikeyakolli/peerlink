package org.peerlink.desktop.identity;

import io.grpc.stub.StreamObserver;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.identity.DeviceIdentityManager;
import org.peerlink.core.identity.IdentityCorruptionException;
import org.peerlink.core.identity.PairingCoordinator;
import org.peerlink.core.security.EncryptedFileKeyStore;
import org.peerlink.core.security.KeyStorageException;
import org.peerlink.core.security.PeerCryptoSigner;
import org.peerlink.core.security.PersistentTrustStore;
import org.peerlink.desktop.ipc.DesktopLocalNodeServiceImpl;
import org.peerlink.desktop.storage.LocalSqliteStorage;
import org.peerlink.protocol.v1.*;

import java.nio.file.Path;
import java.util.Arrays;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

public class DeviceIdentityAndTrustLifecycleTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("Device Identity: Stable Peer ID and keys persist identically across restarts")
    void testIdentityStabilityAcrossRestarts() throws Exception {
        Path dbPath = tempDir.resolve("node.db");
        Path keystoreDir = tempDir.resolve("keystore");
        char[] passphrase = "test-strong-passphrase-12345".toCharArray();

        String peerId1;
        String fingerprint1;
        byte[] pubKey1;
        String keyId1;

        // --- Run 1: First startup / Provisioning ---
        try (LocalSqliteStorage storage1 = new LocalSqliteStorage(dbPath)) {
            EncryptedFileKeyStore keyStore1 = new EncryptedFileKeyStore(keystoreDir, passphrase);
            DeviceIdentityManager idManager1 = DeviceIdentityManager.loadOrCreate(
                    keyStore1, storage1, "Workstation-A", "Windows");

            peerId1 = idManager1.getPeerIdentity().getPeerId().getValue();
            fingerprint1 = idManager1.getFingerprint();
            pubKey1 = idManager1.getSigner().getPublicKeyEncoded();
            keyId1 = idManager1.getSigner().getKeyId();

            assertNotNull(peerId1);
            assertTrue(peerId1.startsWith("peer_"));
            assertEquals(keyId1, idManager1.getDeviceIdentity().getDeviceId().getValue());
        }

        // --- Run 2: Cold restart from disk storage ---
        try (LocalSqliteStorage storage2 = new LocalSqliteStorage(dbPath)) {
            EncryptedFileKeyStore keyStore2 = new EncryptedFileKeyStore(keystoreDir, passphrase);
            DeviceIdentityManager idManager2 = DeviceIdentityManager.loadOrCreate(
                    keyStore2, storage2, "Workstation-A", "Windows");

            String peerId2 = idManager2.getPeerIdentity().getPeerId().getValue();
            String fingerprint2 = idManager2.getFingerprint();
            byte[] pubKey2 = idManager2.getSigner().getPublicKeyEncoded();
            String keyId2 = idManager2.getSigner().getKeyId();

            assertEquals(peerId1, peerId2, "Peer ID MUST be stable across restarts!");
            assertEquals(fingerprint1, fingerprint2, "Fingerprint MUST be stable across restarts!");
            assertArrayEquals(pubKey1, pubKey2, "Public key MUST be stable across restarts!");
            assertEquals(keyId1, keyId2, "Key ID / Device ID MUST be stable across restarts!");
        }
    }

    @Test
    @DisplayName("Device Identity: Versioned deterministic derivation rule v1:ed25519:sha256_16")
    void testDeterministicVersionedDerivationRule() throws Exception {
        Path dbPath = tempDir.resolve("rule_node.db");
        Path keystoreDir = tempDir.resolve("rule_keystore");
        char[] passphrase = "rule-passphrase-xyz".toCharArray();

        try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
            EncryptedFileKeyStore keyStore = new EncryptedFileKeyStore(keystoreDir, passphrase);
            DeviceIdentityManager idManager = DeviceIdentityManager.loadOrCreate(
                    keyStore, storage, "TestDevice", "Windows");

            byte[] pubKey = idManager.getSigner().getPublicKeyEncoded();
            String derived = PeerCryptoSigner.deriveStablePeerId(pubKey);

            assertEquals(derived, idManager.getPeerIdentity().getPeerId().getValue(),
                    "Peer ID must follow the deterministic versioned derivation rule");
            assertEquals("v1:ed25519:sha256_16", storage.loadIdentityMetadata("derivation_rule"));
        }
    }

    @Test
    @DisplayName("Device Identity: Corrupted identity storage fails explicitly without silent regeneration")
    void testIdentityCorruptionStorageRejection() throws Exception {
        Path dbPath = tempDir.resolve("corrupt_node.db");
        Path keystoreDir = tempDir.resolve("corrupt_keystore");
        char[] passphrase = "passphrase-test".toCharArray();

        try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
            EncryptedFileKeyStore keyStore = new EncryptedFileKeyStore(keystoreDir, passphrase);
            DeviceIdentityManager.loadOrCreate(keyStore, storage, "CorruptTest", "Windows");

            // Tamper with SQLite metadata: change the stored fingerprint to a fraudulent value
            storage.saveIdentityMetadata("fingerprint", "TAMPERED_FRAUDULENT_FINGERPRINT_VALUE");
        }

        // On next load, must throw IdentityCorruptionException and NEVER silently overwrite
        try (LocalSqliteStorage storage2 = new LocalSqliteStorage(dbPath)) {
            EncryptedFileKeyStore keyStore2 = new EncryptedFileKeyStore(keystoreDir, passphrase);
            assertThrows(IdentityCorruptionException.class, () ->
                    DeviceIdentityManager.loadOrCreate(keyStore2, storage2, "CorruptTest", "Windows"),
                    "Corrupted identity metadata must fail explicitly without silent re-creation"
            );
        }
    }

    @Test
    @DisplayName("Pairing: Authenticated handshake and verified fingerprint succeeds")
    void testPairingSuccessWithFingerprintVerification() throws Exception {
        // Setup Alice
        Path aliceDb = tempDir.resolve("alice.db");
        Path aliceKs = tempDir.resolve("alice_ks");
        LocalSqliteStorage aliceStorage = new LocalSqliteStorage(aliceDb);
        EncryptedFileKeyStore aliceKeyStore = new EncryptedFileKeyStore(aliceKs, "alice-pass".toCharArray());
        DeviceIdentityManager aliceId = DeviceIdentityManager.loadOrCreate(aliceKeyStore, aliceStorage, "Alice", "Windows");
        PersistentTrustStore aliceTrust = new PersistentTrustStore(tempDir.resolve("alice_trust.pb"));
        PairingCoordinator aliceCoord = new PairingCoordinator(aliceId, aliceTrust);

        // Setup Bob
        Path bobDb = tempDir.resolve("bob.db");
        Path bobKs = tempDir.resolve("bob_ks");
        LocalSqliteStorage bobStorage = new LocalSqliteStorage(bobDb);
        EncryptedFileKeyStore bobKeyStore = new EncryptedFileKeyStore(bobKs, "bob-pass".toCharArray());
        DeviceIdentityManager bobId = DeviceIdentityManager.loadOrCreate(bobKeyStore, bobStorage, "Bob", "Windows");
        PersistentTrustStore bobTrust = new PersistentTrustStore(tempDir.resolve("bob_trust.pb"));
        PairingCoordinator bobCoord = new PairingCoordinator(bobId, bobTrust);

        // Step 1: Alice initiates offer
        PairingOffer offer = aliceCoord.initiatePairing(PairingMethod.PAIRING_METHOD_NUMERIC_CODE, 60_000);
        assertNotNull(offer.getPairingCode());
        assertEquals(aliceId.getFingerprint(), offer.getExpectedFingerprint());

        // Step 2: Bob responds with verified code and fingerprint
        PairingVerification verification = bobCoord.respondToOffer(
                offer, offer.getPairingCode(), offer.getExpectedFingerprint());
        assertNotNull(verification.getVerificationSignature());

        // Step 3: Alice verifies Bob's cryptographic signature and adds Bob to TrustStore
        PairingResult result = aliceCoord.completePairing(verification);
        assertEquals(PairingState.PAIRING_STATE_CONFIRMED, result.getState());
        assertTrue(aliceTrust.isTrusted(bobId.getPeerIdentity().getPeerId().getValue()),
                "Bob MUST be in Alice's TrustStore as trusted after successful handshake");

        aliceStorage.close();
        bobStorage.close();
    }

    @Test
    @DisplayName("Pairing: Fingerprint mismatch rejects pairing and prevents trust establishment")
    void testPairingFailureOnFingerprintMismatch() throws Exception {
        Path aliceDb = tempDir.resolve("alice_fp.db");
        LocalSqliteStorage aliceStorage = new LocalSqliteStorage(aliceDb);
        EncryptedFileKeyStore aliceKeyStore = new EncryptedFileKeyStore(tempDir.resolve("alice_fp_ks"), "pass".toCharArray());
        DeviceIdentityManager aliceId = DeviceIdentityManager.loadOrCreate(aliceKeyStore, aliceStorage, "Alice", "Windows");
        PersistentTrustStore aliceTrust = new PersistentTrustStore(tempDir.resolve("alice_fp_trust.pb"));
        PairingCoordinator aliceCoord = new PairingCoordinator(aliceId, aliceTrust);

        Path bobDb = tempDir.resolve("bob_fp.db");
        LocalSqliteStorage bobStorage = new LocalSqliteStorage(bobDb);
        EncryptedFileKeyStore bobKeyStore = new EncryptedFileKeyStore(tempDir.resolve("bob_fp_ks"), "pass".toCharArray());
        DeviceIdentityManager bobId = DeviceIdentityManager.loadOrCreate(bobKeyStore, bobStorage, "Bob", "Windows");
        PairingCoordinator bobCoord = new PairingCoordinator(bobId, new PersistentTrustStore(tempDir.resolve("bob_fp_trust.pb")));

        PairingOffer offer = aliceCoord.initiatePairing(PairingMethod.PAIRING_METHOD_NUMERIC_CODE, 60_000);

        // Responder provides fraudulent fingerprint
        assertThrows(SecurityException.class, () ->
                bobCoord.respondToOffer(offer, offer.getPairingCode(), "WRONG_FRAUDULENT_FINGERPRINT"),
                "Fingerprint mismatch must trigger SecurityException"
        );

        assertFalse(aliceTrust.isTrusted(bobId.getPeerIdentity().getPeerId().getValue()),
                "Failed pairing must NOT establish trust");

        aliceStorage.close();
        bobStorage.close();
    }

    @Test
    @DisplayName("Trust Invariant: Discovery does NOT imply trust")
    void testDiscoveryDoesNotImplyTrust() {
        PersistentTrustStore trustStore = new PersistentTrustStore(tempDir.resolve("discovery_trust.pb"));
        String discoveredPeerId = "peer_discovered_candidate_999";

        assertFalse(trustStore.isTrusted(discoveredPeerId),
                "Discovered peer must NOT be trusted merely because it was discovered");
        assertFalse(trustStore.isRevoked(discoveredPeerId));
        assertEquals(TrustLevel.TRUST_LEVEL_UNTRUSTED, trustStore.getTrustLevel(discoveredPeerId));
    }

    @Test
    @DisplayName("Local Node: Authoritative trust check blocks transfer initiation to untrusted peers")
    void testAuthoritativeLocalNodeBlocksUntrustedSend() throws Exception {
        PersistentTrustStore trustStore = new PersistentTrustStore(tempDir.resolve("auth_trust.pb"));
        DesktopLocalNodeServiceImpl service = new DesktopLocalNodeServiceImpl(
                "token", "peer_local", 50051, null, null, null, trustStore, null
        );

        InitiateSendRequest request = InitiateSendRequest.newBuilder()
                .setTargetPeerId(PeerId.newBuilder().setValue("peer_untrusted_stranger").build())
                .addSourcePaths("C:\\nonexistent.txt")
                .build();

        CompletableFuture<InitiateSendResponse> future = new CompletableFuture<>();
        service.initiateSend(request, new StreamObserver<InitiateSendResponse>() {
            @Override
            public void onNext(InitiateSendResponse value) { future.complete(value); }
            @Override
            public void onError(Throwable t) { future.completeExceptionally(t); }
            @Override
            public void onCompleted() {}
        });

        InitiateSendResponse response = future.get(3, TimeUnit.SECONDS);
        assertFalse(response.getAccepted(), "Send to untrusted peer must be rejected");
        assertTrue(response.getErrorMessage().contains("not trusted"),
                "Error message must specify peer is not trusted");

        service.close();
    }

    @Test
    @DisplayName("Revocation: Revoking trusted peer immediately blocks operations with explicit semantics")
    void testRevocationExplicitSemantics() throws Exception {
        PersistentTrustStore trustStore = new PersistentTrustStore(tempDir.resolve("revoc_trust.pb"));
        String peerId = "peer_target_alice";

        // Add to trust
        trustStore.addTrustedPeer(peerId, "FP123", new byte[32]);
        assertTrue(trustStore.isTrusted(peerId));
        assertFalse(trustStore.isRevoked(peerId));

        // Revoke peer
        trustStore.revokeTrust(peerId, "Security compromise", null);
        assertTrue(trustStore.isRevoked(peerId), "Peer must be marked as revoked");
        assertFalse(trustStore.isTrusted(peerId), "Revoked peer must NO LONGER be trusted");

        DesktopLocalNodeServiceImpl service = new DesktopLocalNodeServiceImpl(
                "token", "peer_local", 50051, null, null, null, trustStore, null
        );

        InitiateSendRequest request = InitiateSendRequest.newBuilder()
                .setTargetPeerId(PeerId.newBuilder().setValue(peerId).build())
                .addSourcePaths("C:\\file.txt")
                .build();

        CompletableFuture<InitiateSendResponse> future = new CompletableFuture<>();
        service.initiateSend(request, new StreamObserver<InitiateSendResponse>() {
            @Override
            public void onNext(InitiateSendResponse value) { future.complete(value); }
            @Override
            public void onError(Throwable t) { future.completeExceptionally(t); }
            @Override
            public void onCompleted() {}
        });

        InitiateSendResponse response = future.get(3, TimeUnit.SECONDS);
        assertFalse(response.getAccepted(), "Send to revoked peer must be rejected");
        assertTrue(response.getErrorMessage().contains("revoked"),
                "Error message must specify peer is revoked");

        service.close();
    }

    @Test
    @DisplayName("Key Store: Key storage failure handled cleanly when passphrase incorrect")
    void testKeyStoreFailureHandling() {
        Path ksDir = tempDir.resolve("bad_ks");
        assertThrows(KeyStorageException.class, () ->
                new EncryptedFileKeyStore(ksDir, null)
        );
    }
}
