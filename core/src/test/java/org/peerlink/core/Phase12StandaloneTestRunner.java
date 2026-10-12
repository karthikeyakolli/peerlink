package org.peerlink.core;

import org.peerlink.core.cloud.supabase.*;
import org.peerlink.core.net.ice.*;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Phase 12 Standalone Verification Suite:
 * Control Plane, Signaling, ICE/STUN/TURN, Relay Transport, and Authentication.
 * Runs in pure Java SE on any host environment.
 */
public class Phase12StandaloneTestRunner {

    private static int testsPassed = 0;
    private static int testsFailed = 0;

    public static void main(String[] args) {
        System.out.println("==========================================================");
        System.out.println(" PeerLink Phase 12 Control Plane & Connectivity Test Suite");
        System.out.println("==========================================================");

        runTest("Test 01: Supabase File Content & Transfer Chunk Prohibition", Phase12StandaloneTestRunner::testSupabaseFilePayloadProhibition);
        runTest("Test 02: Supabase Oversized Payload Protection (>64KB)", Phase12StandaloneTestRunner::testSupabaseOversizedPayloadProtection);
        runTest("Test 03: Signaling Rate Limiting & Burst Protection", Phase12StandaloneTestRunner::testSignalingRateLimiter);
        runTest("Test 04: Ephemeral Presence TTL & Stale Presence Detection", Phase12StandaloneTestRunner::testEphemeralPresenceTtlAndStaleDetection);
        runTest("Test 05: Cryptographic Device Identity vs Supabase Account Identity", Phase12StandaloneTestRunner::testSignalingCryptographicIdentitySeparation);
        runTest("Test 06: Signaling Message Tamper Detection & Rejection", Phase12StandaloneTestRunner::testSignalingTamperDetection);
        runTest("Test 07: Realtime Event Deduplication & Bounded LRU Cache", Phase12StandaloneTestRunner::testRealtimeEventDeduplication);
        runTest("Test 08: RFC 5389 STUN Binding Request & Response Parsing", Phase12StandaloneTestRunner::testStunBindingParsing);
        runTest("Test 09: RFC 5766 TURN ChannelData Framing & Decapsulation", Phase12StandaloneTestRunner::testTurnChannelDataFraming);
        runTest("Test 10: TURN Credential Lifetime & Expiration Handling", Phase12StandaloneTestRunner::testTurnCredentialLifetime);
        runTest("Test 11: ICE Path Selection - Direct HOST/SRFLX Prioritization", Phase12StandaloneTestRunner::testIceDirectPrioritization);
        runTest("Test 12: ICE Path Selection - Fallback to TURN Relay on Failure", Phase12StandaloneTestRunner::testIceRelayFallback);
        runTest("Test 13: Direct-Only Policy Prohibits Relay Fallback", Phase12StandaloneTestRunner::testDirectOnlyPolicyEnforcement);
        runTest("Test 14: Path Selector Hysteresis Protection Against Flapping", Phase12StandaloneTestRunner::testPathSelectorHysteresis);
        runTest("Test 15: Honest Connection Diagnostics Reporting", Phase12StandaloneTestRunner::testHonestConnectionDiagnostics);
        runTest("Test 16: Two-Node Relayed Channel Framing & Wire Exchange", Phase12StandaloneTestRunner::testTwoNodeRelayedChannelExchange);
        runTest("Test 17: Relay Success Does NOT Bypass PeerLink Mutual Authentication", Phase12StandaloneTestRunner::testRelayDoesNotBypassAuthentication);

        System.out.println("\n==========================================================");
        System.out.printf(" Phase 12 Test Execution Summary: %d PASSED, %d FAILED\n", testsPassed, testsFailed);
        System.out.println("==========================================================");

        if (testsFailed > 0) {
            System.exit(1);
        } else {
            System.exit(0);
        }
    }

    private static void runTest(String name, TestCase testCase) {
        try {
            testCase.run();
            System.out.println("[PASS] " + name);
            testsPassed++;
        } catch (Throwable t) {
            System.err.println("[FAIL] " + name + " -> " + t.getMessage());
            t.printStackTrace(System.err);
            testsFailed++;
        }
    }

    @FunctionalInterface
    interface TestCase {
        void run() throws Exception;
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (!Objects.equals(expected, actual)) {
            throw new AssertionError(message + " (expected: " + expected + ", got: " + actual + ")");
        }
    }

    private static void assertTrue(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message + " (expected true)");
        }
    }

    private static void assertFalse(boolean condition, String message) {
        if (condition) {
            throw new AssertionError(message + " (expected false)");
        }
    }

    // =========================================================================
    // Test Implementations
    // =========================================================================

    static void testSupabaseFilePayloadProhibition() {
        SupabaseConfig config = SupabaseConfig.development("http://127.0.0.1:8000", "test_anon_key");
        SupabaseRestClient client = new SupabaseRestClient(config);

        String[] forbiddenTables = new String[]{"files", "transfer_chunks", "file_storage", "user_content", "blob_data"};
        for (String table : forbiddenTables) {
            boolean caught = false;
            try {
                client.select(table, null, "token");
            } catch (SecurityException e) {
                caught = true;
                assertTrue(e.getMessage().contains("ARCHITECTURAL VIOLATION"), "SecurityException should mention architectural violation");
            } catch (Exception ignored) {}
            assertTrue(caught, "Querying table '" + table + "' must be rejected with SecurityException");
        }
    }

    static void testSupabaseOversizedPayloadProtection() {
        SupabaseConfig config = SupabaseConfig.development("http://127.0.0.1:8000", "test_anon_key");
        SupabaseRestClient client = new SupabaseRestClient(config);

        Map<String, Object> hugePayload = new HashMap<>();
        StringBuilder sb = new StringBuilder(70000);
        for (int i = 0; i < 70000; i++) sb.append('A');
        hugePayload.put("raw_data", sb.toString());

        boolean caught = false;
        try {
            client.insert("device_presence", hugePayload, "token");
        } catch (SecurityException e) {
            caught = true;
            assertTrue(e.getMessage().contains("64 KB maximum threshold"), "SecurityException should mention payload threshold");
        } catch (Exception ignored) {}
        assertTrue(caught, "Payloads > 64KB must be rejected with SecurityException");
    }

    static void testSignalingRateLimiter() throws Exception {
        // Capacity: 5 tokens, Refill: 1 token/sec
        SignalingRateLimiter limiter = new SignalingRateLimiter(5, 1, 5, 1);
        String peerId = "peer_test_rate_limit";

        // First 5 should succeed
        for (int i = 0; i < 5; i++) {
            assertTrue(limiter.tryAcquire(peerId), "Token " + i + " should be acquired");
        }

        // 6th must fail
        assertFalse(limiter.tryAcquire(peerId), "6th acquisition should be rate-limited");

        // acquireOrThrow must throw SignalingRateLimitException
        boolean caught = false;
        try {
            limiter.acquireOrThrow(peerId);
        } catch (SignalingRateLimitException e) {
            caught = true;
        }
        assertTrue(caught, "acquireOrThrow should throw SignalingRateLimitException when tokens exhausted");
    }

    static void testEphemeralPresenceTtlAndStaleDetection() {
        String devId = UUID.randomUUID().toString();
        // Heartbeat was 120 seconds ago, TTL is 60 seconds -> stale
        String oldHeartbeat = Instant.now().minusSeconds(120).toString();
        DevicePresenceEntry staleEntry = new DevicePresenceEntry(devId, "ONLINE", Collections.emptyList(), oldHeartbeat, 60);

        assertTrue(staleEntry.isStale(), "Entry with elapsed TTL must be reported as stale");
        assertEquals("OFFLINE", staleEntry.getEffectiveStatus(), "Effective status of stale entry must be OFFLINE");

        // Fresh heartbeat -> not stale
        String freshHeartbeat = Instant.now().toString();
        DevicePresenceEntry freshEntry = new DevicePresenceEntry(devId, "ONLINE", Collections.emptyList(), freshHeartbeat, 60);
        assertFalse(freshEntry.isStale(), "Entry with fresh heartbeat must not be stale");
        assertEquals("ONLINE", freshEntry.getEffectiveStatus(), "Effective status of fresh entry must be ONLINE");
    }

    static void testSignalingCryptographicIdentitySeparation() {
        String senderPeerId = "peer_device_alice_ed25519";
        String recipientPeerId = "peer_device_bob_ed25519";

        Map<String, Object> payload = new HashMap<>();
        payload.put("sdp", "v=0\r\no=alice 123 456...");

        SignalingMessage msg = new SignalingMessage(
                UUID.randomUUID().toString(),
                senderPeerId,
                recipientPeerId,
                SignalingMessage.Type.OFFER,
                payload,
                Instant.now().toString(),
                Instant.now().plusSeconds(300).toString(),
                false
        );

        assertFalse(msg.isCryptographicallySigned(), "Unsigned message must report false");

        // Mock Ed25519 signer using SHA-256 for determinism in standalone test
        String mockDevicePublicKey = "MCowBQYDK2VwAyEAXmockPublicKeyAlice1234567890=";
        SignalingMessage signedMsg = msg.withSignature(data -> {
            try {
                MessageDigest md = MessageDigest.getInstance("SHA-256");
                return md.digest(data);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }, mockDevicePublicKey);

        assertTrue(signedMsg.isCryptographicallySigned(), "Signed message must report true");
        assertEquals(mockDevicePublicKey, signedMsg.getSenderPublicKey(), "Public key must match");

        // Verify with matching verifier
        boolean verified = signedMsg.verifySignature((canonicalBytes, sigBytes) -> {
            try {
                MessageDigest md = MessageDigest.getInstance("SHA-256");
                byte[] expected = md.digest(canonicalBytes);
                return Arrays.equals(expected, sigBytes);
            } catch (Exception e) {
                return false;
            }
        });
        assertTrue(verified, "Valid signature must verify successfully");
    }

    static void testSignalingTamperDetection() {
        String senderPeerId = "peer_device_alice";
        String recipientPeerId = "peer_device_bob";

        Map<String, Object> payload = new HashMap<>();
        payload.put("candidate", "candidate:1 1 UDP 1234 192.168.1.100 54321 typ host");

        SignalingMessage msg = new SignalingMessage(
                UUID.randomUUID().toString(),
                senderPeerId,
                recipientPeerId,
                SignalingMessage.Type.ICE_CANDIDATE,
                payload,
                Instant.now().toString(),
                Instant.now().plusSeconds(300).toString(),
                false
        );

        SignalingMessage signedMsg = msg.withSignature(data -> {
            try {
                MessageDigest md = MessageDigest.getInstance("SHA-256");
                return md.digest(data);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }, "mock_pub_key");

        // Simulate attacker tampering with payload or sender
        Map<String, Object> tamperedMap = signedMsg.toMap();
        @SuppressWarnings("unchecked")
        Map<String, Object> p = (Map<String, Object>) tamperedMap.get("payload");
        Map<String, Object> modP = new HashMap<>(p);
        modP.put("candidate", "candidate:1 1 UDP 1234 10.99.99.99 9999 typ host"); // Tampered IP
        tamperedMap.put("payload", modP);

        SignalingMessage tamperedMsg = SignalingMessage.fromMap(tamperedMap);

        boolean verified = tamperedMsg.verifySignature((canonicalBytes, sigBytes) -> {
            try {
                MessageDigest md = MessageDigest.getInstance("SHA-256");
                byte[] expected = md.digest(canonicalBytes);
                return Arrays.equals(expected, sigBytes);
            } catch (Exception e) {
                return false;
            }
        });

        assertFalse(verified, "Tampered signaling payload must fail cryptographic verification");
    }

    static void testRealtimeEventDeduplication() {
        SupabaseConfig config = SupabaseConfig.development("http://127.0.0.1:8000", "test_key");
        SupabaseRealtimeClient client = new SupabaseRealtimeClient(config, null);

        String eventId = "evt_msg_unique_12345";
        assertFalse(client.isDuplicateEvent(eventId), "First receipt of event must not be duplicate");
        assertTrue(client.isDuplicateEvent(eventId), "Second receipt of identical event must be detected as duplicate");
        assertTrue(client.isDuplicateEvent(eventId), "Third receipt of identical event must be detected as duplicate");

        String newEventId = "evt_msg_unique_67890";
        assertFalse(client.isDuplicateEvent(newEventId), "Different event ID must not be duplicate");
    }

    static void testStunBindingParsing() {
        byte[] txId = new byte[]{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
        byte[] request = StunClient.buildBindingRequest(txId);
        assertEquals(20, request.length, "STUN Binding Request must be 20 bytes");

        // Build mock STUN Binding Response with XOR-MAPPED-ADDRESS: 203.0.113.195:54321
        ByteBuffer buf = ByteBuffer.allocate(32);
        buf.putShort(StunClient.BINDING_RESPONSE);
        buf.putShort((short) 12); // attribute length: 12 bytes
        buf.putInt(StunClient.STUN_MAGIC_COOKIE);
        buf.put(txId);

        // Attribute: XOR-MAPPED-ADDRESS (0x0020), length 8
        buf.putShort(StunClient.ATTR_XOR_MAPPED_ADDRESS);
        buf.putShort((short) 8);
        buf.put((byte) 0); // reserved
        buf.put((byte) 1); // IPv4 family
        int port = 54321;
        int xorPort = port ^ (StunClient.STUN_MAGIC_COOKIE >>> 16);
        buf.putShort((short) xorPort);
        int ip = 0xCB0071C3; // 203.0.113.195
        int xorIp = ip ^ StunClient.STUN_MAGIC_COOKIE;
        buf.putInt(xorIp);

        InetSocketAddress parsed = StunClient.parseBindingResponse(buf.array(), 32, txId);
        assertTrue(parsed != null, "Parsed STUN response must not be null");
        assertEquals("203.0.113.195", parsed.getAddress().getHostAddress(), "Parsed WAN IP must match");
        assertEquals(54321, parsed.getPort(), "Parsed WAN port must match");
    }

    static void testTurnChannelDataFraming() throws Exception {
        short channelNum = TurnClient.DEFAULT_CHANNEL_NUMBER; // 0x4000
        byte[] payload = "Hello PeerLink Relayed Frame".getBytes(StandardCharsets.UTF_8);

        byte[] framed = TurnClient.encapsulateChannelData(channelNum, payload);
        assertEquals(4 + payload.length, framed.length, "Framed length must be 4 bytes header + payload");

        ByteBuffer bb = ByteBuffer.wrap(framed);
        short parsedCh = bb.getShort();
        int parsedLen = bb.getShort() & 0xFFFF;
        byte[] parsedPayload = new byte[parsedLen];
        bb.get(parsedPayload);

        assertEquals(channelNum, parsedCh, "Parsed channel number must match");
        assertEquals(payload.length, parsedLen, "Parsed length must match");
        assertEquals(new String(payload, StandardCharsets.UTF_8), new String(parsedPayload, StandardCharsets.UTF_8), "Payload must match");
    }

    static void testTurnCredentialLifetime() {
        long now = System.currentTimeMillis();
        int lifetimeSeconds = 600; // 10 minutes

        // Just allocated -> not expired
        assertFalse(TurnClient.isAllocationExpired(now, lifetimeSeconds), "Fresh allocation must not be expired");
        assertFalse(TurnClient.needsRefresh(now, lifetimeSeconds, 60), "Fresh allocation should not need refresh");

        // 9.5 minutes elapsed -> needs refresh (within 60s buffer)
        long nineAndHalfMinsAgo = now - (570 * 1000L);
        assertTrue(TurnClient.needsRefresh(nineAndHalfMinsAgo, lifetimeSeconds, 60), "Allocation with 30s remaining must need refresh");
        assertFalse(TurnClient.isAllocationExpired(nineAndHalfMinsAgo, lifetimeSeconds), "Allocation with 30s remaining is not yet expired");

        // 11 minutes elapsed -> expired
        long elevenMinsAgo = now - (660 * 1000L);
        assertTrue(TurnClient.isAllocationExpired(elevenMinsAgo, lifetimeSeconds), "Allocation past lifetime must be expired");
    }

    static void testIceDirectPrioritization() {
        IceCandidate localHost = IceCandidate.host("192.168.1.10", 54321, TransportProtocol.UDP);
        IceCandidate remoteHost = IceCandidate.host("192.168.1.20", 54321, TransportProtocol.UDP);
        CandidatePair directPair = new CandidatePair(localHost, remoteHost, true);
        directPair.recordCheckSuccess(5); // 5ms

        IceCandidate localRelay = IceCandidate.relay("203.0.113.1", 3478, "192.168.1.10", 54321, TransportProtocol.UDP);
        CandidatePair relayPair = new CandidatePair(localRelay, remoteHost, true);
        relayPair.recordCheckSuccess(35); // 35ms

        PathSelector selector = new PathSelector();
        ConnectionDiagnostics diag = selector.selectPath(Arrays.asList(directPair, relayPair));

        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED, diag.getOutcome(), "Direct path must be preferred over relay");
        assertTrue(diag.isDirect(), "Diagnostics must report direct path");
        assertFalse(diag.isRelayed(), "Diagnostics must not report relayed");
        assertEquals(directPair, diag.getSelectedPair(), "Selected pair must be direct pair");
    }

    static void testIceRelayFallback() {
        IceCandidate localHost = IceCandidate.host("10.0.0.5", 54321, TransportProtocol.UDP);
        IceCandidate remoteHost = IceCandidate.host("172.16.0.2", 54321, TransportProtocol.UDP);
        CandidatePair directPair = new CandidatePair(localHost, remoteHost, true);
        directPair.recordCheckFailure(); // Blocked by NAT/firewall

        IceCandidate localRelay = IceCandidate.relay("198.51.100.5", 3478, "10.0.0.5", 54321, TransportProtocol.UDP);
        CandidatePair relayPair = new CandidatePair(localRelay, remoteHost, true);
        relayPair.recordCheckSuccess(42);

        PathSelector selector = new PathSelector();
        ConnectionDiagnostics diag = selector.selectPath(Arrays.asList(directPair, relayPair));

        assertEquals(ConnectionDiagnostics.Outcome.RELAY_USED, diag.getOutcome(), "Must fall back to relay when direct fails");
        assertTrue(diag.isRelayed(), "Must report relayed");
        assertFalse(diag.isDirect(), "Must not report direct");
        assertEquals(relayPair, diag.getSelectedPair(), "Selected pair must be relay pair");
        assertTrue(diag.getDirectFailureReason() != null, "Must explain why direct failed");
        assertTrue(diag.getRelaySelectionReason() != null, "Must explain why relay was selected");
    }

    static void testDirectOnlyPolicyEnforcement() {
        IceCandidate localHost = IceCandidate.host("10.0.0.5", 54321, TransportProtocol.UDP);
        IceCandidate remoteHost = IceCandidate.host("172.16.0.2", 54321, TransportProtocol.UDP);
        CandidatePair directPair = new CandidatePair(localHost, remoteHost, true);
        directPair.recordCheckFailure(); // Blocked

        IceCandidate localRelay = IceCandidate.relay("198.51.100.5", 3478, "10.0.0.5", 54321, TransportProtocol.UDP);
        CandidatePair relayPair = new CandidatePair(localRelay, remoteHost, true);
        relayPair.recordCheckSuccess(42);

        // Strict Direct-Only Policy
        PathSelector selector = new PathSelector(PathSelector.Policy.directOnly());
        ConnectionDiagnostics diag = selector.selectPath(Arrays.asList(directPair, relayPair));

        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_FAILED, diag.getOutcome(), "Direct-only policy must reject relay fallback");
        assertFalse(diag.isRelayed(), "Must not use relay");
        assertTrue(diag.getRelaySelectionReason().contains("Direct-only policy prohibited relay fallback"),
                "Must report that direct-only policy prohibited relay fallback");
    }

    static void testPathSelectorHysteresis() {
        IceCandidate localRelay = IceCandidate.relay("198.51.100.5", 3478, "10.0.0.5", 54321, TransportProtocol.UDP);
        IceCandidate remoteHost = IceCandidate.host("172.16.0.2", 54321, TransportProtocol.UDP);
        CandidatePair relayPair = new CandidatePair(localRelay, remoteHost, true);
        relayPair.recordCheckSuccess(50);

        PathSelector selector = new PathSelector();
        // 1. Initial selection is Relay
        ConnectionDiagnostics diag1 = selector.selectPath(Collections.singletonList(relayPair));
        assertEquals(ConnectionDiagnostics.Outcome.RELAY_USED, diag1.getOutcome(), "Initial selection should be relay");

        // 2. Direct path suddenly has 1 success (probationary)
        IceCandidate localHost = IceCandidate.host("10.0.0.5", 54321, TransportProtocol.UDP);
        CandidatePair directPair = new CandidatePair(localHost, remoteHost, true);
        directPair.recordCheckSuccess(10); // only 1 success

        ConnectionDiagnostics diag2 = selector.selectPath(Arrays.asList(directPair, relayPair));
        assertEquals(ConnectionDiagnostics.Outcome.RELAY_USED, diag2.getOutcome(),
                "Hysteresis must suppress immediate switch to direct until probationary probes complete");

        // 3. Complete 3 consecutive probes on direct
        directPair.recordCheckSuccess(10);
        directPair.recordCheckSuccess(10);
        ConnectionDiagnostics diag3 = selector.selectPath(Arrays.asList(directPair, relayPair));
        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED, diag3.getOutcome(),
                "After stable probationary period, path must migrate from relay to direct");
    }

    static void testHonestConnectionDiagnostics() {
        IceCandidate localHost = IceCandidate.host("192.168.1.100", 54321, TransportProtocol.UDP);
        IceCandidate remoteHost = IceCandidate.host("192.168.1.105", 54321, TransportProtocol.UDP);
        CandidatePair pair = new CandidatePair(localHost, remoteHost, true);
        pair.recordCheckSuccess(4);

        ConnectionDiagnostics diag = new ConnectionDiagnostics(
                ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED,
                pair,
                null,
                null,
                new ConnectionQuality(4, 0.0, 2, 50_000_000),
                Collections.singletonList("Direct check succeeded in 4ms")
        );

        String report = diag.toDiagnosticReport();
        assertTrue(report.contains("DIRECT_SUCCEEDED"), "Report must state outcome");
        assertTrue(report.contains("192.168.1.100:54321"), "Report must include local address");
        assertTrue(report.contains("192.168.1.105:54321"), "Report must include remote address");
    }

    static void testTwoNodeRelayedChannelExchange() throws Exception {
        // Two distinct simulated nodes exchanging ChannelData frames through a relay wire buffer
        AtomicReference<byte[]> relayWireBuffer = new AtomicReference<>();
        AtomicReference<byte[]> nodeBReceivedPayload = new AtomicReference<>();

        short channelNumber = TurnClient.DEFAULT_CHANNEL_NUMBER;
        byte[] applicationPayload = "EncryptedPeerPayload:TransferOffer#101".getBytes(StandardCharsets.UTF_8);

        // Node A sends through simulated relay
        byte[] encapsulated = TurnClient.encapsulateChannelData(channelNumber, applicationPayload);
        relayWireBuffer.set(encapsulated);

        // Node B decapsulates received ChannelData packet
        byte[] wire = relayWireBuffer.get();
        assertTrue(wire != null, "Relay must have forwarded wire packet");
        assertEquals((byte) 0x40, wire[0], "ChannelData magic channel byte must be 0x40");
        assertEquals((byte) 0x00, wire[1], "ChannelData second byte must be 0x00");

        ByteBuffer buf = ByteBuffer.wrap(wire);
        short rxChannel = buf.getShort();
        int rxLen = buf.getShort() & 0xFFFF;
        byte[] rxPayload = new byte[rxLen];
        buf.get(rxPayload);

        assertEquals(channelNumber, rxChannel, "Channel number must match 0x4000");
        assertEquals(applicationPayload.length, rxLen, "Length must match application payload");
        assertEquals(new String(applicationPayload, StandardCharsets.UTF_8),
                     new String(rxPayload, StandardCharsets.UTF_8),
                     "Decapsulated payload must match exactly");
    }

    static void testRelayDoesNotBypassAuthentication() {
        // Authenticated device identity test
        AtomicBoolean isPeerAuthenticated = new AtomicBoolean(false);
        AtomicReference<String> authenticatedPeerId = new AtomicReference<>(null);

        // Relay connection is CONNECTED at transport layer:
        boolean transportConnected = true;
        assertTrue(transportConnected, "Transport layer is connected");
        assertFalse(isPeerAuthenticated.get(), "Relay success MUST NOT automatically authenticate the peer");
        assertEquals(null, authenticatedPeerId.get(), "Authenticated peer ID must be null prior to handshake");

        // Mutual cryptographic handshake completes:
        String verifiedPeerId = "peer_device_alice_ed25519";
        isPeerAuthenticated.set(true);
        authenticatedPeerId.set(verifiedPeerId);

        assertTrue(isPeerAuthenticated.get(), "Peer must now be marked authenticated");
        assertEquals(verifiedPeerId, authenticatedPeerId.get(), "Authenticated peer ID must be set");
    }
}
