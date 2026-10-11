package org.peerlink.core.identity;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.security.*;
import org.peerlink.core.transport.PeerSession;
import org.peerlink.core.transport.PeerSessionManager;
import org.peerlink.core.transport.TransportCapabilityNegotiator;
import org.peerlink.core.transport.TransportConnection;
import org.peerlink.protocol.v1.*;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.file.Path;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

public class IdentityTrustAndPairingTest {

    @TempDir
    Path tempDir;

    private ProtocolVersion v1;
    private InMemorySecureKeyStore aliceKeyStore;
    private InMemorySecureKeyStore bobKeyStore;
    private DeviceIdentityManager aliceIdentity;
    private DeviceIdentityManager bobIdentity;
    private InMemoryTrustStore aliceTrustStore;
    private InMemoryTrustStore bobTrustStore;

    @BeforeEach
    void setUp() throws Exception {
        v1 = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build();

        aliceKeyStore = new InMemorySecureKeyStore();
        bobKeyStore = new InMemorySecureKeyStore();

        aliceIdentity = DeviceIdentityManager.createNew(
                aliceKeyStore,
                "Alice Workstation",
                DeviceType.DEVICE_TYPE_DESKTOP_WINDOWS,
                "Windows 11",
                "0.1.0"
        );

        bobIdentity = DeviceIdentityManager.createNew(
                bobKeyStore,
                "Bob Mobile",
                DeviceType.DEVICE_TYPE_MOBILE_ANDROID,
                "Android 14",
                "0.1.0"
        );

        aliceTrustStore = new InMemoryTrustStore();
        bobTrustStore = new InMemoryTrustStore();
    }

    @AfterEach
    void tearDown() {
        if (aliceKeyStore != null) aliceKeyStore.close();
        if (bobKeyStore != null) bobKeyStore.close();
    }

    @Test
    void testPairTwoDevicesViaNumericCode() {
        PairingCoordinator alicePairing = new PairingCoordinator(aliceIdentity, aliceTrustStore);
        PairingCoordinator bobPairing = new PairingCoordinator(bobIdentity, bobTrustStore);

        // 1. Alice initiates pairing offer (numeric code, 60s TTL)
        PairingOffer offer = alicePairing.initiatePairing(PairingMethod.PAIRING_METHOD_NUMERIC_CODE, 60_000);
        assertNotNull(offer);
        assertEquals(PairingState.PAIRING_STATE_OFFERED, alicePairing.getSessionState(offer.getPairingSessionId()));
        assertFalse(offer.getPairingCode().isBlank());
        assertEquals(6, offer.getPairingCode().length());
        assertTrue(offer.getExpectedFingerprint().startsWith("SHA256:"));

        // 2. Bob receives offer, user enters the 6-digit code and confirms fingerprint
        PairingVerification verification = bobPairing.respondToOffer(
                offer,
                offer.getPairingCode(),
                aliceIdentity.getFingerprint()
        );
        assertNotNull(verification);

        // Bob trusts Alice upon responding
        bobTrustStore.addTrustedPeer(offer.getInitiatorPeer());
        assertTrue(bobTrustStore.isTrusted(aliceIdentity.getPeerIdentity().getPeerId().getValue()));

        // 3. Alice verifies Bob's verification and commits to TrustStore
        PairingResult result = alicePairing.completePairing(verification);
        assertEquals(PairingState.PAIRING_STATE_CONFIRMED, result.getState());
        assertEquals(PairingState.PAIRING_STATE_CONFIRMED, alicePairing.getSessionState(offer.getPairingSessionId()));

        // Alice now trusts Bob
        assertTrue(aliceTrustStore.isTrusted(bobIdentity.getPeerIdentity().getPeerId().getValue()));
        assertEquals(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED,
                aliceTrustStore.getTrustLevel(bobIdentity.getPeerIdentity().getPeerId().getValue()));
    }

    @Test
    void testPairTwoDevicesViaQrCode() {
        PairingCoordinator alicePairing = new PairingCoordinator(aliceIdentity, aliceTrustStore);
        PairingCoordinator bobPairing = new PairingCoordinator(bobIdentity, bobTrustStore);

        // Alice initiates QR pairing offer
        PairingOffer offer = alicePairing.initiatePairing(PairingMethod.PAIRING_METHOD_QR_CODE, 60_000);
        assertTrue(offer.getQrPayload().startsWith("peerlink://pair?session="));
        assertTrue(offer.getQrPayload().contains("fp=" + aliceIdentity.getFingerprint()));

        // Bob scans QR code (parsing code & fingerprint directly from payload)
        PairingVerification verification = bobPairing.respondToOffer(
                offer,
                offer.getPairingCode(),
                offer.getExpectedFingerprint()
        );

        PairingResult result = alicePairing.completePairing(verification);
        assertEquals(PairingState.PAIRING_STATE_CONFIRMED, result.getState());
        assertTrue(aliceTrustStore.isTrusted(bobIdentity.getPeerIdentity().getPeerId().getValue()));
    }

    @Test
    void testRejectWrongFingerprint() {
        PairingCoordinator alicePairing = new PairingCoordinator(aliceIdentity, aliceTrustStore);
        PairingCoordinator bobPairing = new PairingCoordinator(bobIdentity, bobTrustStore);

        PairingOffer offer = alicePairing.initiatePairing(PairingMethod.PAIRING_METHOD_NUMERIC_CODE, 60_000);

        // Bob provides a spoofed/wrong fingerprint
        String wrongFingerprint = "SHA256:0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff";
        SecurityException ex = assertThrows(SecurityException.class, () ->
                bobPairing.respondToOffer(offer, offer.getPairingCode(), wrongFingerprint)
        );
        assertTrue(ex.getMessage().contains("Fingerprint verification failed"));
        assertFalse(aliceTrustStore.isTrusted(bobIdentity.getPeerIdentity().getPeerId().getValue()));
    }

    @Test
    void testRejectWrongPairingCode() {
        PairingCoordinator alicePairing = new PairingCoordinator(aliceIdentity, aliceTrustStore);
        PairingCoordinator bobPairing = new PairingCoordinator(bobIdentity, bobTrustStore);

        PairingOffer offer = alicePairing.initiatePairing(PairingMethod.PAIRING_METHOD_NUMERIC_CODE, 60_000);

        // Bob provides incorrect code
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                bobPairing.respondToOffer(offer, "999999", aliceIdentity.getFingerprint())
        );
        assertTrue(ex.getMessage().contains("Invalid pairing code"));
    }

    @Test
    void testRevokePeerAndEnforceInSessionManager() throws Exception {
        // 1. Initial pairing
        aliceTrustStore.addTrustedPeer(bobIdentity.getPeerIdentity());
        assertTrue(aliceTrustStore.isTrusted(bobIdentity.getPeerIdentity().getPeerId().getValue()));
        assertEquals(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED,
                aliceTrustStore.getTrustLevel(bobIdentity.getPeerIdentity().getPeerId().getValue()));

        // 2. Alice revokes Bob
        aliceTrustStore.revokeTrust(bobIdentity.getPeerIdentity().getPeerId().getValue(), "Security compromise", new byte[0]);
        assertFalse(aliceTrustStore.isTrusted(bobIdentity.getPeerIdentity().getPeerId().getValue()));
        assertTrue(aliceTrustStore.isRevoked(bobIdentity.getPeerIdentity().getPeerId().getValue()));
        assertEquals(TrustLevel.TRUST_LEVEL_REVOKED,
                aliceTrustStore.getTrustLevel(bobIdentity.getPeerIdentity().getPeerId().getValue()));

        // 3. Attempt session handshake after revocation -> must be rejected
        PeerSessionManager aliceManager = new PeerSessionManager(
                aliceIdentity.getPeerIdentity(),
                aliceIdentity.getDeviceIdentity(),
                aliceIdentity.getSigner(),
                aliceTrustStore,
                v1,
                v1,
                new TransportCapabilityNegotiator(Collections.emptyList())
        );

        // Bob attempts to initiate a session with Alice
        MockTransportConnection mockConn = new MockTransportConnection();
        aliceManager.handleInboundConnection(mockConn);

        // Send Bob's SYN to Alice
        String sessId = "sess_revocation_test";
        long now = System.currentTimeMillis();
        byte[] nonce = PeerCryptoSigner.generateNonce(32);
        byte[] sig = bobIdentity.getSigner().signChallenge(
                bobIdentity.getPeerIdentity().getPeerId().getValue(),
                mockConn.getConnectionId().getValue(),
                sessId,
                nonce,
                now
        );

        HandshakeFrame syn = HandshakeFrame.newBuilder()
                .setPhase(HandshakePhase.HANDSHAKE_PHASE_SYN)
                .setProtocolVersion(v1)
                .setMinSupportedVersion(v1)
                .setSessionId(SessionId.newBuilder().setValue(sessId).build())
                .setConnectionId(mockConn.getConnectionId())
                .setPeerIdentity(bobIdentity.getPeerIdentity())
                .setDeviceIdentity(bobIdentity.getDeviceIdentity())
                .setNonce(com.google.protobuf.ByteString.copyFrom(nonce))
                .setTimestampUtcMs(now)
                .setSignature(com.google.protobuf.ByteString.copyFrom(sig))
                .build();

        mockConn.simulateInboundFrame(TransportFrame.newBuilder().setHandshake(syn).build());

        TransportFrame sentFrame = mockConn.getSentFrameFuture().get(3, TimeUnit.SECONDS);
        assertNotNull(sentFrame);
        assertTrue(sentFrame.hasHandshake());
        HandshakeFrame rejectFrame = sentFrame.getHandshake();
        assertEquals(HandshakePhase.HANDSHAKE_PHASE_REJECT, rejectFrame.getPhase());
        assertEquals(ErrorCode.ERROR_CODE_UNAUTHORIZED, rejectFrame.getError().getCode());
        assertTrue(rejectFrame.getError().getHumanExplanation().contains("not in trusted paired store"));
    }

    @Test
    void testRestartNodeAndPreserveTrustState() throws Exception {
        Path storeFile = tempDir.resolve("persistent_trust_store.pb");

        // First session: add trusted peer and a revocation
        PersistentTrustStore store1 = new PersistentTrustStore(storeFile);
        store1.addTrustedPeer(bobIdentity.getPeerIdentity());
        store1.revokeTrust("peer_evil_hacker", "Compromised key", new byte[0]);

        assertTrue(store1.isTrusted(bobIdentity.getPeerIdentity().getPeerId().getValue()));
        assertTrue(store1.isRevoked("peer_evil_hacker"));

        // Simulate node restart: instantiate a new PersistentTrustStore reading the same file
        PersistentTrustStore store2 = new PersistentTrustStore(storeFile);
        assertTrue(store2.isTrusted(bobIdentity.getPeerIdentity().getPeerId().getValue()),
                "Trusted peer must survive node restart");
        assertTrue(store2.isRevoked("peer_evil_hacker"),
                "Revocation must survive node restart");
        assertEquals(bobIdentity.getFingerprint(),
                store2.getFingerprint(bobIdentity.getPeerIdentity().getPeerId().getValue()).orElseThrow());
    }

    @Test
    void testBackupAndRestoreTrustMetadata() throws Exception {
        InMemoryTrustStore sourceStore = new InMemoryTrustStore();
        sourceStore.addTrustedPeer(bobIdentity.getPeerIdentity());
        sourceStore.revokeTrust("peer_rogue", "Lost device", new byte[0]);

        // Export signed trust snapshot
        byte[] backupBytes = sourceStore.exportTrustSnapshot(aliceIdentity.getSigner());
        assertNotNull(backupBytes);
        assertTrue(backupBytes.length > 0);

        // Restore onto fresh trust store
        InMemoryTrustStore restoredStore = new InMemoryTrustStore();
        assertFalse(restoredStore.isTrusted(bobIdentity.getPeerIdentity().getPeerId().getValue()));

        restoredStore.importTrustSnapshot(backupBytes, aliceIdentity.getSigner().getPublicKeyBytes());
        assertTrue(restoredStore.isTrusted(bobIdentity.getPeerIdentity().getPeerId().getValue()),
                "Restored store must trust Bob");
        assertTrue(restoredStore.isRevoked("peer_rogue"),
                "Restored store must preserve revocation");
    }

    @Test
    void testAccountBindingIndependence() {
        // Supabase account identity != PeerLink cryptographic device identity
        PeerIdentity boundPeer = aliceIdentity.bindAccount("usr_supabase_12345", "alice@example.com");

        assertTrue(boundPeer.hasAccountBinding());
        assertEquals("usr_supabase_12345", boundPeer.getAccountBinding().getAccountId());
        assertEquals("alice@example.com", boundPeer.getAccountBinding().getAccountEmail());
        assertFalse(boundPeer.getAccountBinding().getOwnershipProofSignature().isEmpty());

        // Cryptographic identity, peer ID, and key remain unchanged
        assertEquals(aliceIdentity.getPeerIdentity().getPeerId(), boundPeer.getPeerId());
        assertEquals(aliceIdentity.getFingerprint(), boundPeer.getFingerprintHex());
    }

    @Test
    void testClonedIdentityDetection() {
        InMemoryTrustStore store = new InMemoryTrustStore();
        store.addTrustedPeer(bobIdentity.getPeerIdentity());

        // Attacker creates a fresh key but claims Bob's Peer ID
        PeerCryptoSigner attackerSigner = PeerCryptoSigner.generate("key_attacker");
        PeerIdentity clonedBob = PeerIdentity.newBuilder()
                .setPeerId(bobIdentity.getPeerIdentity().getPeerId()) // Same Peer ID
                .setDisplayName("Bob Impostor")
                .setFingerprintHex(attackerSigner.getFingerprintHex())
                .setIdentityKey(attackerSigner.toProtobufKey(System.currentTimeMillis())) // Differing key!
                .build();

        SecurityException ex = assertThrows(SecurityException.class, () -> store.addTrustedPeer(clonedBob));
        assertTrue(ex.getMessage().contains("Cloned identity detected"));
    }

    @Test
    void testEncryptedFileKeyStoreZeroCleartext() throws Exception {
        Path keyDir = tempDir.resolve("secure_keystore");
        char[] passphrase = "test-passphrase-random-12345".toCharArray();

        EncryptedFileKeyStore keyStore = new EncryptedFileKeyStore(keyDir, passphrase);
        byte[] secretKey = "super-secret-ed25519-private-key-material-32b".getBytes();

        keyStore.storePrivateKey("key_alice_priv", secretKey);
        assertTrue(keyStore.hasKey("key_alice_priv"));

        // Retrieve and verify
        byte[] retrieved = keyStore.getPrivateKey("key_alice_priv");
        assertArrayEquals(secretKey, retrieved);

        // Verify on disk that raw private key bytes do not appear in cleartext
        File keyFile = keyDir.resolve("key_alice_priv.key").toFile();
        assertTrue(keyFile.exists());
        byte[] diskBytes = java.nio.file.Files.readAllBytes(keyFile.toPath());
        assertFalse(new String(diskBytes).contains("super-secret-ed25519"));

        keyStore.deleteKey("key_alice_priv");
        assertFalse(keyStore.hasKey("key_alice_priv"));
        keyStore.close();
    }

    @Test
    void testMalformedIdentityValidation() {
        assertThrows(IllegalArgumentException.class, () ->
                DeviceIdentityManager.validateIdentityRecord(PeerIdentity.getDefaultInstance()));

        PeerIdentity noKey = PeerIdentity.newBuilder()
                .setPeerId(PeerId.newBuilder().setValue("peer_123").build())
                .build();
        assertThrows(IllegalArgumentException.class, () -> DeviceIdentityManager.validateIdentityRecord(noKey));

        PeerIdentity badFp = PeerIdentity.newBuilder()
                .setPeerId(PeerId.newBuilder().setValue("peer_123").build())
                .setIdentityKey(CryptographicKey.newBuilder().setPublicKeyBytes(com.google.protobuf.ByteString.copyFromUtf8("key")).build())
                .setFingerprintHex("MD5:bad_format")
                .build();
        assertThrows(IllegalArgumentException.class, () -> DeviceIdentityManager.validateIdentityRecord(badFp));
    }

    // Helper mock transport connection
    private static class MockTransportConnection implements TransportConnection {
        private final ConnectionId connectionId = ConnectionId.newBuilder().setValue("conn_mock_123").build();
        private org.peerlink.core.transport.TransportFrameHandler handler;
        private TransportFrame lastSent;
        private final CompletableFuture<TransportFrame> sentFrameFuture = new CompletableFuture<>();

        @Override public ConnectionId getConnectionId() { return connectionId; }
        @Override public TransportType getTransportType() { return TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS; }
        @Override public org.peerlink.core.transport.ConnectionState getState() { return org.peerlink.core.transport.ConnectionState.CONNECTED; }
        @Override public InetSocketAddress getRemoteAddress() { return new InetSocketAddress("127.0.0.1", 9999); }
        @Override public InetSocketAddress getLocalAddress() { return new InetSocketAddress("127.0.0.1", 8888); }
        @Override public void setFrameHandler(org.peerlink.core.transport.TransportFrameHandler handler) { this.handler = handler; }
        @Override public void addLifecycleListener(org.peerlink.core.transport.ConnectionLifecycleListener listener) {}
        @Override public CompletableFuture<Void> sendFrameAsync(TransportFrame frame) {
            this.lastSent = frame;
            sentFrameFuture.complete(frame);
            return CompletableFuture.completedFuture(null);
        }
        public CompletableFuture<TransportFrame> getSentFrameFuture() {
            return sentFrameFuture;
        }
        public void simulateInboundFrame(TransportFrame frame) {
            if (handler != null) handler.handleFrame(this, frame);
        }
        @Override public CompletableFuture<Void> closeAsync() { return CompletableFuture.completedFuture(null); }
        @Override public void close() {}
    }
}
