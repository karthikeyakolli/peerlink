package org.peerlink.desktop.transport;

import com.google.protobuf.ByteString;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.peerlink.core.security.InMemoryTrustStore;
import org.peerlink.core.security.PeerCryptoSigner;
import org.peerlink.core.transport.PeerSession;
import org.peerlink.core.transport.PeerSessionManager;
import org.peerlink.core.transport.TransportCapabilityNegotiator;
import org.peerlink.core.transport.TransportConnection;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;

/**
 * End-to-end transport and secure session tests for Phase 03:
 * Proves that two local PeerLink nodes establish and authenticate a session using the transport abstraction.
 */
public class SecureSessionTransportTest {

    private static final Logger log = LoggerFactory.getLogger(SecureSessionTransportTest.class);

    private ProtocolVersion v1_0_0;
    private ProtocolVersion v2_0_0;

    // Node A (Alice)
    private PeerCryptoSigner aliceSigner;
    private PeerIdentity alicePeer;
    private DeviceIdentity aliceDevice;
    private InMemoryTrustStore aliceTrustStore;
    private DesktopQuicTransportProvider aliceQuic;
    private NettyTcpTlsTransportProvider aliceTcp;
    private PeerSessionManager aliceSessionManager;

    // Node B (Bob)
    private PeerCryptoSigner bobSigner;
    private PeerIdentity bobPeer;
    private DeviceIdentity bobDevice;
    private InMemoryTrustStore bobTrustStore;
    private DesktopQuicTransportProvider bobQuic;
    private NettyTcpTlsTransportProvider bobTcp;
    private PeerSessionManager bobSessionManager;

    @BeforeEach
    void setUp() {
        v1_0_0 = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build();
        v2_0_0 = ProtocolVersion.newBuilder().setMajor(2).setMinor(0).setPatch(0).build();

        long now = System.currentTimeMillis();

        // Setup Alice
        aliceSigner = PeerCryptoSigner.generate("key_alice_01");
        DeviceId aliceDevId = DeviceId.newBuilder().setValue("dev_alice_pc").build();
        PeerId aliceId = PeerId.newBuilder().setValue("peer_alice").build();
        aliceDevice = DeviceIdentity.newBuilder()
                .setDeviceId(aliceDevId)
                .setDeviceName("Alice Desktop")
                .setDeviceType(DeviceType.DEVICE_TYPE_DESKTOP_WINDOWS)
                .setOsVersion("Windows 10")
                .setAppVersion("0.1.0")
                .setIdentityKey(aliceSigner.toProtobufKey(now))
                .build();
        alicePeer = PeerIdentity.newBuilder()
                .setPeerId(aliceId)
                .setDeviceId(aliceDevId)
                .setDisplayName("Alice")
                .setIdentityKey(aliceSigner.toProtobufKey(now))
                .setFingerprintHex(aliceSigner.computeFingerprint())
                .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                .setPairedAtUtcMs(now)
                .build();
        aliceTrustStore = new InMemoryTrustStore();
        aliceQuic = new DesktopQuicTransportProvider();
        aliceTcp = new NettyTcpTlsTransportProvider();
        aliceSessionManager = new PeerSessionManager(
                alicePeer,
                aliceDevice,
                aliceSigner,
                aliceTrustStore,
                v1_0_0,
                v1_0_0,
                new TransportCapabilityNegotiator(List.of(aliceQuic, aliceTcp))
        );

        // Setup Bob
        bobSigner = PeerCryptoSigner.generate("key_bob_01");
        DeviceId bobDevId = DeviceId.newBuilder().setValue("dev_bob_pc").build();
        PeerId bobId = PeerId.newBuilder().setValue("peer_bob").build();
        bobDevice = DeviceIdentity.newBuilder()
                .setDeviceId(bobDevId)
                .setDeviceName("Bob Desktop")
                .setDeviceType(DeviceType.DEVICE_TYPE_DESKTOP_LINUX)
                .setOsVersion("Linux 6.8")
                .setAppVersion("0.1.0")
                .setIdentityKey(bobSigner.toProtobufKey(now))
                .build();
        bobPeer = PeerIdentity.newBuilder()
                .setPeerId(bobId)
                .setDeviceId(bobDevId)
                .setDisplayName("Bob")
                .setIdentityKey(bobSigner.toProtobufKey(now))
                .setFingerprintHex(bobSigner.computeFingerprint())
                .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
                .setPairedAtUtcMs(now)
                .build();
        bobTrustStore = new InMemoryTrustStore();
        bobQuic = new DesktopQuicTransportProvider();
        bobTcp = new NettyTcpTlsTransportProvider();
        bobSessionManager = new PeerSessionManager(
                bobPeer,
                bobDevice,
                bobSigner,
                bobTrustStore,
                v1_0_0,
                v1_0_0,
                new TransportCapabilityNegotiator(List.of(bobQuic, bobTcp))
        );

        // Cross-register trust (pairing complete)
        aliceTrustStore.addTrustedPeer(bobPeer.getPeerId().getValue(), bobPeer.getFingerprintHex(), bobSigner.getPublicKeyEncoded());
        bobTrustStore.addTrustedPeer(alicePeer.getPeerId().getValue(), alicePeer.getFingerprintHex(), aliceSigner.getPublicKeyEncoded());
    }

    @AfterEach
    void tearDown() {
        if (aliceSessionManager != null) aliceSessionManager.close();
        if (bobSessionManager != null) bobSessionManager.close();
        if (aliceQuic != null) aliceQuic.close();
        if (aliceTcp != null) aliceTcp.close();
        if (bobQuic != null) bobQuic.close();
        if (bobTcp != null) bobTcp.close();
    }

    @Test
    void testDirectQuicConnection() throws Exception {
        // Bob starts listening on QUIC UDP port
        bobQuic.startListening(0, conn -> bobSessionManager.handleInboundConnection(conn));
        int bobPort = bobQuic.getListeningPort();
        assertTrue(bobPort > 0);

        // Alice connects via QUIC
        TransportConnection transportConn = aliceQuic.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);
        assertNotNull(transportConn);
        assertEquals(TransportType.TRANSPORT_TYPE_DIRECT_QUIC, transportConn.getTransportType());

        // Alice initiates mutual authenticated session
        PeerSession aliceSession = aliceSessionManager.initiateSessionAsync(transportConn).get(5, TimeUnit.SECONDS);
        assertNotNull(aliceSession);
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, aliceSession.getState());
        assertEquals(TransportType.TRANSPORT_TYPE_DIRECT_QUIC, aliceSession.getActiveTransportType());
        assertEquals("peer_bob", aliceSession.getRemotePeer().getPeerId().getValue());

        // Verify Bob also has established session
        Thread.sleep(100);
        PeerSession bobSession = bobSessionManager.getSessionByPeerId("peer_alice").orElseThrow();
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, bobSession.getState());
        assertEquals(aliceSession.getSessionId().getValue(), bobSession.getSessionId().getValue());

        // Test payload transmission over QUIC session
        CountDownLatch payloadLatch = new CountDownLatch(1);
        AtomicReference<String> receivedPayload = new AtomicReference<>();
        bobSession.setPayloadHandler((sess, payload) -> {
            receivedPayload.set(new String(payload, StandardCharsets.UTF_8));
            payloadLatch.countDown();
        });

        aliceSession.sendPayloadAsync("Hello from Alice over Direct QUIC!".getBytes(StandardCharsets.UTF_8)).get(2, TimeUnit.SECONDS);
        assertTrue(payloadLatch.await(3, TimeUnit.SECONDS), "Bob should receive payload over QUIC");
        assertEquals("Hello from Alice over Direct QUIC!", receivedPayload.get());

        // Test keepalive ping/pong measurement
        Long rttMs = aliceSession.sendPingAsync().get(3, TimeUnit.SECONDS);
        assertNotNull(rttMs);
        assertTrue(rttMs >= 0);

        // Test graceful close
        aliceSession.closeAsync(0, "Test finished").get(2, TimeUnit.SECONDS);
        assertEquals(SessionState.SESSION_STATE_CLOSED, aliceSession.getState());
    }

    @Test
    void testTcpTlsFallback() throws Exception {
        // Disable QUIC on Alice to trigger capability fallback to TCP/TLS
        aliceQuic.setAvailable(false);

        // Bob starts listening on TCP
        bobTcp.startListening(0, conn -> bobSessionManager.handleInboundConnection(conn));
        int bobPort = bobTcp.getListeningPort();
        assertTrue(bobPort > 0);

        // Alice attempts to connect; capability negotiation falls back to TCP
        TransportConnection transportConn = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);
        assertNotNull(transportConn);
        assertEquals(TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS, transportConn.getTransportType());

        PeerSession aliceSession = aliceSessionManager.initiateSessionAsync(transportConn).get(5, TimeUnit.SECONDS);
        assertNotNull(aliceSession);
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, aliceSession.getState());
        assertEquals(TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS, aliceSession.getActiveTransportType());

        // Verify Bob side
        Thread.sleep(100);
        PeerSession bobSession = bobSessionManager.getSessionByPeerId("peer_alice").orElseThrow();
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, bobSession.getState());

        // Payload exchange over TCP
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<String> received = new AtomicReference<>();
        bobSession.setPayloadHandler((s, p) -> {
            received.set(new String(p, StandardCharsets.UTF_8));
            latch.countDown();
        });

        aliceSession.sendPayloadAsync("Payload over TCP/TLS fallback".getBytes(StandardCharsets.UTF_8)).get(2, TimeUnit.SECONDS);
        assertTrue(latch.await(3, TimeUnit.SECONDS));
        assertEquals("Payload over TCP/TLS fallback", received.get());
    }

    @Test
    void testInvalidCertificateOrIdentitySignatureRejected() throws Exception {
        bobTcp.startListening(0, conn -> bobSessionManager.handleInboundConnection(conn));
        int bobPort = bobTcp.getListeningPort();

        // Attacker Mallory has a fake key and tries to impersonate Alice
        PeerCryptoSigner attackerSigner = PeerCryptoSigner.generate("key_mallory");
        TransportConnection conn = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);

        // Attacker creates SYN with Alice's peerId but signed with Mallory's key
        long now = System.currentTimeMillis();
        byte[] fakeSig = attackerSigner.signChallenge("peer_alice", conn.getConnectionId().getValue(), "sess_fake", new byte[32], now);

        HandshakeFrame forgedSyn = HandshakeFrame.newBuilder()
                .setPhase(HandshakePhase.HANDSHAKE_PHASE_SYN)
                .setProtocolVersion(v1_0_0)
                .setMinSupportedVersion(v1_0_0)
                .setConnectionId(conn.getConnectionId())
                .setSessionId(SessionId.newBuilder().setValue("sess_fake").build())
                .setPeerIdentity(alicePeer) // Claims to be Alice
                .setDeviceIdentity(aliceDevice)
                .setNonce(ByteString.copyFrom(new byte[32]))
                .setTimestampUtcMs(now)
                .setSignature(ByteString.copyFrom(fakeSig)) // But signed by Mallory!
                .build();

        CountDownLatch rejectLatch = new CountDownLatch(1);
        AtomicReference<ErrorCode> rejectCode = new AtomicReference<>();
        conn.setFrameHandler((c, frame) -> {
            if (frame.hasHandshake() && frame.getHandshake().getPhase() == HandshakePhase.HANDSHAKE_PHASE_REJECT) {
                rejectCode.set(frame.getHandshake().getError().getCode());
                rejectLatch.countDown();
            }
        });

        conn.sendFrameAsync(TransportFrame.newBuilder().setHandshake(forgedSyn).build()).get();
        assertTrue(rejectLatch.await(3, TimeUnit.SECONDS), "Bob must reject forged identity signature");
        assertEquals(ErrorCode.ERROR_CODE_UNAUTHENTICATED, rejectCode.get());
        assertTrue(bobSessionManager.getActiveSessions().isEmpty(), "No session should be established");
    }

    @Test
    void testUntrustedPeerIdentityRejected() throws Exception {
        bobTcp.startListening(0, conn -> bobSessionManager.handleInboundConnection(conn));
        int bobPort = bobTcp.getListeningPort();

        // Peer Charlie is valid cryptographically, but NOT paired in Bob's TrustStore
        PeerCryptoSigner charlieSigner = PeerCryptoSigner.generate("key_charlie");
        PeerIdentity charliePeer = PeerIdentity.newBuilder()
                .setPeerId(PeerId.newBuilder().setValue("peer_charlie").build())
                .setDeviceId(DeviceId.newBuilder().setValue("dev_charlie").build())
                .setDisplayName("Charlie Stranger")
                .setIdentityKey(charlieSigner.toProtobufKey(System.currentTimeMillis()))
                .build();

        PeerSessionManager charlieManager = new PeerSessionManager(
                charliePeer,
                DeviceIdentity.getDefaultInstance(),
                charlieSigner,
                new InMemoryTrustStore(),
                v1_0_0,
                v1_0_0,
                new TransportCapabilityNegotiator(List.of(aliceTcp))
        );

        TransportConnection conn = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);

        CompletableFuture<PeerSession> sessionFuture = charlieManager.initiateSessionAsync(conn);
        ExecutionException ex = assertThrows(ExecutionException.class, () -> sessionFuture.get(5, TimeUnit.SECONDS));
        assertTrue(ex.getMessage().contains("ERROR_CODE_UNAUTHORIZED") || ex.getMessage().contains("not in trusted paired store"),
                "Must reject untrusted peer (discovery != trust): " + ex.getMessage());
    }

    @Test
    void testMalformedHandshakeRejected() throws Exception {
        bobTcp.startListening(0, conn -> bobSessionManager.handleInboundConnection(conn));
        int bobPort = bobTcp.getListeningPort();

        TransportConnection conn = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);

        // Malformed SYN frame (missing identity, nonce, and signature)
        HandshakeFrame malformedSyn = HandshakeFrame.newBuilder()
                .setPhase(HandshakePhase.HANDSHAKE_PHASE_SYN)
                .setProtocolVersion(v1_0_0)
                .build();

        CountDownLatch rejectLatch = new CountDownLatch(1);
        AtomicReference<ErrorCode> rejectCode = new AtomicReference<>();
        conn.setFrameHandler((c, frame) -> {
            if (frame.hasHandshake() && frame.getHandshake().getPhase() == HandshakePhase.HANDSHAKE_PHASE_REJECT) {
                rejectCode.set(frame.getHandshake().getError().getCode());
                rejectLatch.countDown();
            }
        });

        conn.sendFrameAsync(TransportFrame.newBuilder().setHandshake(malformedSyn).build()).get();
        assertTrue(rejectLatch.await(3, TimeUnit.SECONDS), "Bob must reject malformed handshake");
        assertEquals(ErrorCode.ERROR_CODE_UNAUTHENTICATED, rejectCode.get());
    }

    @Test
    void testReplayProtection() throws Exception {
        bobTcp.startListening(0, conn -> bobSessionManager.handleInboundConnection(conn));
        int bobPort = bobTcp.getListeningPort();

        TransportConnection conn1 = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);

        // Capture a valid SYN frame
        long now = System.currentTimeMillis();
        byte[] nonce = PeerCryptoSigner.generateNonce(32);
        String sessId = "sess_replay_test";
        byte[] sig = aliceSigner.signChallenge("peer_alice", conn1.getConnectionId().getValue(), sessId, nonce, now);

        HandshakeFrame syn = HandshakeFrame.newBuilder()
                .setPhase(HandshakePhase.HANDSHAKE_PHASE_SYN)
                .setProtocolVersion(v1_0_0)
                .setMinSupportedVersion(v1_0_0)
                .setConnectionId(conn1.getConnectionId())
                .setSessionId(SessionId.newBuilder().setValue(sessId).build())
                .setPeerIdentity(alicePeer)
                .setDeviceIdentity(aliceDevice)
                .setNonce(ByteString.copyFrom(nonce))
                .setTimestampUtcMs(now)
                .setSignature(ByteString.copyFrom(sig))
                .build();

        // 1st time: accepted (Bob responds with SYN_ACK)
        CountDownLatch synAckLatch = new CountDownLatch(1);
        conn1.setFrameHandler((c, frame) -> {
            if (frame.hasHandshake() && frame.getHandshake().getPhase() == HandshakePhase.HANDSHAKE_PHASE_SYN_ACK) {
                synAckLatch.countDown();
            }
        });
        conn1.sendFrameAsync(TransportFrame.newBuilder().setHandshake(syn).build()).get();
        assertTrue(synAckLatch.await(3, TimeUnit.SECONDS));

        // 2nd time: replay attack with identical nonce over new connection
        TransportConnection conn2 = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);
        CountDownLatch rejectLatch = new CountDownLatch(1);
        AtomicReference<ErrorCode> rejectCode = new AtomicReference<>();
        conn2.setFrameHandler((c, frame) -> {
            if (frame.hasHandshake() && frame.getHandshake().getPhase() == HandshakePhase.HANDSHAKE_PHASE_REJECT) {
                rejectCode.set(frame.getHandshake().getError().getCode());
                rejectLatch.countDown();
            }
        });

        conn2.sendFrameAsync(TransportFrame.newBuilder().setHandshake(syn).build()).get();
        assertTrue(rejectLatch.await(3, TimeUnit.SECONDS), "Replayed nonce must be rejected");
        assertEquals(ErrorCode.ERROR_CODE_UNAUTHENTICATED, rejectCode.get());
    }

    @Test
    void testProtocolVersionMismatch() throws Exception {
        bobTcp.startListening(0, conn -> bobSessionManager.handleInboundConnection(conn));
        int bobPort = bobTcp.getListeningPort();

        TransportConnection conn = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);

        // Alice client claims protocol version 2.0.0 (incompatible major version)
        PeerSessionManager v2Manager = new PeerSessionManager(
                alicePeer,
                aliceDevice,
                aliceSigner,
                aliceTrustStore,
                v2_0_0, // Incompatible major version!
                v2_0_0,
                new TransportCapabilityNegotiator(List.of(aliceTcp))
        );

        CompletableFuture<PeerSession> sessionFuture = v2Manager.initiateSessionAsync(conn);
        ExecutionException ex = assertThrows(ExecutionException.class, () -> sessionFuture.get(5, TimeUnit.SECONDS));
        assertTrue(ex.getMessage().contains("ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION") ||
                        ex.getMessage().contains("Incompatible protocol version"),
                "Must reject incompatible protocol version: " + ex.getMessage());
    }

    @Test
    void testDuplicateSessionAttemptRejected() throws Exception {
        bobTcp.startListening(0, conn -> bobSessionManager.handleInboundConnection(conn));
        int bobPort = bobTcp.getListeningPort();

        // 1st session: established successfully
        TransportConnection conn1 = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);
        PeerSession session1 = aliceSessionManager.initiateSessionAsync(conn1).get(5, TimeUnit.SECONDS);
        assertNotNull(session1);
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, session1.getState());

        // 2nd session attempt for the same peer ID while 1st is still active
        TransportConnection conn2 = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);
        CompletableFuture<PeerSession> session2Future = aliceSessionManager.initiateSessionAsync(conn2);

        ExecutionException ex = assertThrows(ExecutionException.class, () -> session2Future.get(5, TimeUnit.SECONDS));
        assertTrue(ex.getMessage().contains("ERROR_CODE_CONFLICT_DETECTED") ||
                        ex.getMessage().contains("Duplicate") ||
                        ex.getMessage().contains("conflict"),
                "Must reject duplicate session attempt: " + ex.getMessage());
    }

    @Test
    void testDisconnectAndReconnectSkeleton() throws Exception {
        bobTcp.startListening(0, conn -> bobSessionManager.handleInboundConnection(conn));
        int bobPort = bobTcp.getListeningPort();

        // 1. Establish session
        TransportConnection conn1 = aliceTcp.connectAsync(new InetSocketAddress("127.0.0.1", bobPort)).get(3, TimeUnit.SECONDS);
        PeerSession session1 = aliceSessionManager.initiateSessionAsync(conn1).get(5, TimeUnit.SECONDS);
        assertNotNull(session1);
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, session1.getState());

        // 2. Disconnect connection
        session1.closeAsync(0, "Simulated network drop").get(2, TimeUnit.SECONDS);
        assertEquals(SessionState.SESSION_STATE_CLOSED, session1.getState());

        // Wait for session deregistration
        Thread.sleep(150);
        assertTrue(bobSessionManager.getSessionByPeerId("peer_alice").isEmpty());

        // 3. Reconnect skeleton re-establishes session with backoff
        PeerSession reconnectedSession = aliceSessionManager.reconnectAsync(
                aliceTcp,
                new InetSocketAddress("127.0.0.1", bobPort),
                3
        ).get(5, TimeUnit.SECONDS);

        assertNotNull(reconnectedSession);
        assertEquals(SessionState.SESSION_STATE_ESTABLISHED, reconnectedSession.getState());
        assertEquals("peer_bob", reconnectedSession.getRemotePeer().getPeerId().getValue());
    }
}
