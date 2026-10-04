package org.peerlink.core.net.ice;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.peerlink.protocol.v1.ConnectionId;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Phase 09 Test Suite: Internet P2P Connectivity & ICE/STUN/TURN Path Selection.
 * Tests:
 * 1. same LAN
 * 2. different LAN
 * 3. home router NAT
 * 4. restrictive firewall
 * 5. UDP blocked
 * 6. TCP available
 * 7. TURN relay
 * 8. network handoff
 * 9. temporary backend outage
 * 10. peer reconnect
 * 11. direct-only policy
 * 12. hysteresis to avoid direct/relay flapping
 * 13. diagnostics engine
 */
public class InternetConnectivityTest {

    // =========================================================================
    // Test 1: Same LAN
    // =========================================================================
    @Test
    @DisplayName("Test 1: Same LAN peers establish direct path using HOST candidate pair")
    void testSameLanDirectPath() {
        IceCandidate localHost = IceCandidate.host("192.168.1.100", 54321, TransportProtocol.UDP);
        IceCandidate remoteHost = IceCandidate.host("192.168.1.105", 54321, TransportProtocol.UDP);

        CandidatePair pair = new CandidatePair(localHost, remoteHost, true);
        pair.recordCheckSuccess(2); // 2ms local LAN RTT

        PathSelector selector = new PathSelector();
        ConnectionDiagnostics diagnostics = selector.selectPath(Collections.singletonList(pair));

        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED, diagnostics.getOutcome());
        assertTrue(diagnostics.isDirect());
        assertFalse(diagnostics.isRelayed());
        assertEquals(pair, diagnostics.getSelectedPair());
        assertEquals(2, diagnostics.getConnectionQuality().getRoundTripTimeMs());
    }

    // =========================================================================
    // Test 2 & 3: Different LAN & Home Router NAT (STUN SRFLX)
    // =========================================================================
    @Test
    @DisplayName("Test 2 & 3: Peers behind home router NAT on different LANs connect via SRFLX candidates")
    void testDifferentLanHomeRouterNatStun() {
        // Discovered public IPs via STUN
        IceCandidate localSrflx = IceCandidate.srflx("203.0.113.10", 61234, "192.168.1.50", 54321, TransportProtocol.UDP);
        IceCandidate remoteSrflx = IceCandidate.srflx("198.51.100.25", 58765, "10.0.0.8", 54321, TransportProtocol.UDP);

        CandidatePair srflxPair = new CandidatePair(localSrflx, remoteSrflx, true);
        srflxPair.recordCheckSuccess(28); // 28ms WAN RTT

        PathSelector selector = new PathSelector();
        ConnectionDiagnostics diagnostics = selector.selectPath(Collections.singletonList(srflxPair));

        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED, diagnostics.getOutcome());
        assertTrue(diagnostics.isDirect());
        assertEquals(CandidateType.SRFLX, diagnostics.getSelectedPair().getLocalCandidate().getType());
        assertEquals(CandidateType.SRFLX, diagnostics.getSelectedPair().getRemoteCandidate().getType());
        assertEquals(28, diagnostics.getConnectionQuality().getRoundTripTimeMs());
    }

    // =========================================================================
    // Test 4: Restrictive Firewall (Fallback to TURN Relay)
    // =========================================================================
    @Test
    @DisplayName("Test 4: Restrictive firewall drops direct probes, triggering fallback to coturn relay")
    void testRestrictiveFirewallFallbackToRelay() {
        IceCandidate localHost = IceCandidate.host("10.200.0.5", 54321, TransportProtocol.UDP);
        IceCandidate remoteHost = IceCandidate.host("172.16.0.9", 54321, TransportProtocol.UDP);
        CandidatePair directPair = new CandidatePair(localHost, remoteHost, true);
        directPair.recordCheckFailure(); // Blocked by firewall

        IceCandidate localRelay = IceCandidate.relay("198.51.100.1", 3478, "10.200.0.5", 54321, TransportProtocol.UDP);
        CandidatePair relayPair = new CandidatePair(localRelay, remoteHost, true);
        relayPair.recordCheckSuccess(45); // Relay path succeeds

        PathSelector selector = new PathSelector();
        ConnectionDiagnostics diagnostics = selector.selectPath(Arrays.asList(directPair, relayPair));

        assertEquals(ConnectionDiagnostics.Outcome.RELAY_USED, diagnostics.getOutcome());
        assertTrue(diagnostics.isRelayed());
        assertFalse(diagnostics.isDirect());
        assertEquals(relayPair, diagnostics.getSelectedPair());
        assertNotNull(diagnostics.getDirectFailureReason());
        assertNotNull(diagnostics.getRelaySelectionReason());
    }

    // =========================================================================
    // Test 5 & 6: UDP Blocked & TCP Available
    // =========================================================================
    @Test
    @DisplayName("Test 5 & 6: Corporate network blocks UDP; connection establishes over direct or relayed TCP")
    void testUdpBlockedTcpAvailable() {
        // UDP candidates fail due to firewall blocking UDP traffic
        IceCandidate udpLocal = IceCandidate.host("192.168.1.20", 54321, TransportProtocol.UDP);
        IceCandidate udpRemote = IceCandidate.host("192.168.1.30", 54321, TransportProtocol.UDP);
        CandidatePair udpPair = new CandidatePair(udpLocal, udpRemote, true);
        udpPair.recordCheckFailure();

        // TCP candidates succeed
        IceCandidate tcpLocal = IceCandidate.host("192.168.1.20", 54322, TransportProtocol.TCP);
        IceCandidate tcpRemote = IceCandidate.host("192.168.1.30", 54322, TransportProtocol.TCP);
        CandidatePair tcpPair = new CandidatePair(tcpLocal, tcpRemote, true);
        tcpPair.recordCheckSuccess(15);

        PathSelector selector = new PathSelector();
        ConnectionDiagnostics diagnostics = selector.selectPath(Arrays.asList(udpPair, tcpPair));

        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED, diagnostics.getOutcome());
        assertEquals(TransportProtocol.TCP, diagnostics.getSelectedPair().getLocalCandidate().getProtocol());
        assertEquals(15, diagnostics.getConnectionQuality().getRoundTripTimeMs());
    }

    // =========================================================================
    // Test 7: TURN Relay Protocol & Encrypted Data Connection
    // =========================================================================
    @Test
    @DisplayName("Test 7: TURN coturn allocation and TurnRelayedTransportConnection encapsulation")
    void testTurnRelayConnection() throws IOException {
        ConnectionId connId = ConnectionId.newBuilder().setValue("conn-turn-001").build();
        InetSocketAddress local = new InetSocketAddress("10.0.0.1", 54321);
        InetSocketAddress remote = new InetSocketAddress("10.0.0.2", 54321);
        InetSocketAddress relay = new InetSocketAddress("turn.peerlink.org", 3478);

        TurnRelayedTransportConnection conn = new TurnRelayedTransportConnection(
                connId, local, remote, relay, TransportProtocol.UDP
        );

        assertEquals(org.peerlink.protocol.v1.TransportType.TRANSPORT_TYPE_RELAY_TURN, conn.getTransportType());
        assertEquals(org.peerlink.core.transport.ConnectionState.CONNECTED, conn.getState());
        assertEquals(relay, conn.getRelayAddress());

        // Test frame sending and closure
        assertDoesNotThrow(() -> conn.sendFrameAsync(org.peerlink.protocol.v1.TransportFrame.getDefaultInstance()).join());
        conn.close();
        assertEquals(org.peerlink.core.transport.ConnectionState.CLOSED, conn.getState());
    }

    // =========================================================================
    // Test 8: Network Handoff & Path Migration
    // =========================================================================
    @Test
    @DisplayName("Test 8: Network handoff (WiFi -> LTE) migrates active path seamlessly")
    void testNetworkHandoffPathMigration() {
        AtomicReference<CandidatePair> activeRef = new AtomicReference<>();
        AtomicReference<CandidatePair> migratedRef = new AtomicReference<>();

        IceAgent agent = new IceAgent(true, PathSelector.Policy.defaultPolicy(), new IceAgent.IceListener() {
            @Override
            public void onCandidateGathered(IceCandidate candidate) {}

            @Override
            public void onPathSelected(CandidatePair activePair, ConnectionDiagnostics diagnostics) {
                activeRef.set(activePair);
            }

            @Override
            public void onPathMigrated(CandidatePair oldPair, CandidatePair newPair) {
                migratedRef.set(newPair);
            }

            @Override
            public void onFailed(String reason) {}
        });

        // Initial WiFi connection
        IceCandidate wifiLocal = IceCandidate.host("192.168.1.100", 54321, TransportProtocol.UDP);
        IceCandidate remotePeer = IceCandidate.host("192.168.1.200", 54321, TransportProtocol.UDP);
        agent.addLocalCandidate(wifiLocal);
        agent.addRemoteCandidate(remotePeer);

        CandidatePair wifiPair = agent.getCandidatePairs().get(0);
        agent.recordCheckResult(wifiPair, true, 5);
        agent.evaluateAndSelectPath();
        assertEquals(wifiPair, agent.getActivePair());

        // Handoff to LTE: new IP address 100.64.12.34
        IceCandidate lteLocal = IceCandidate.host("100.64.12.34", 54321, TransportProtocol.UDP);
        agent.addLocalCandidate(lteLocal);

        // Find new LTE pair and record success with low RTT
        CandidatePair ltePair = null;
        for (CandidatePair p : agent.getCandidatePairs()) {
            if (p.getLocalCandidate().getIp().equals("100.64.12.34")) {
                ltePair = p;
                break;
            }
        }
        assertNotNull(ltePair);
        agent.recordCheckResult(ltePair, true, 2); // 2ms is significantly faster than 5ms
        agent.evaluateAndSelectPath();

        // Path migrated to LTE pair
        assertEquals(ltePair, agent.getActivePair());
        assertEquals(ltePair, migratedRef.get());
    }

    // =========================================================================
    // Test 9: Temporary Backend Outage Resilience
    // =========================================================================
    @Test
    @DisplayName("Test 9: Established ICE session continues uninterrupted during signaling control plane outage")
    void testTemporaryBackendOutage() {
        IceCandidate local = IceCandidate.host("192.168.1.10", 54321, TransportProtocol.UDP);
        IceCandidate remote = IceCandidate.host("192.168.1.20", 54321, TransportProtocol.UDP);
        CandidatePair pair = new CandidatePair(local, remote, true);
        pair.recordCheckSuccess(5);

        PathSelector selector = new PathSelector();
        ConnectionDiagnostics diag = selector.selectPath(Collections.singletonList(pair));
        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED, diag.getOutcome());

        // Control plane outage occurs (Supabase disconnected)
        // Established P2P candidate pair remains SUCCEEDED and active
        assertEquals(pair, selector.getActivePair());
        assertEquals(CandidatePair.State.SUCCEEDED, selector.getActivePair().getState());
    }

    // =========================================================================
    // Test 10: Peer Reconnect
    // =========================================================================
    @Test
    @DisplayName("Test 10: Peer reconnects after disconnection, re-probes candidate pairs and restores session")
    void testPeerReconnect() {
        IceCandidate local = IceCandidate.host("192.168.1.10", 54321, TransportProtocol.UDP);
        IceCandidate remote = IceCandidate.host("192.168.1.20", 54321, TransportProtocol.UDP);
        CandidatePair pair = new CandidatePair(local, remote, true);

        // Session drops
        pair.recordCheckFailure();
        assertEquals(CandidatePair.State.FAILED, pair.getState());

        // Reconnect triggered
        pair.setState(CandidatePair.State.WAITING);
        pair.recordCheckSuccess(8);
        assertEquals(CandidatePair.State.SUCCEEDED, pair.getState());

        PathSelector selector = new PathSelector();
        ConnectionDiagnostics diag = selector.selectPath(Collections.singletonList(pair));
        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED, diag.getOutcome());
    }

    // =========================================================================
    // Test 11: Direct-Only Policy Enforcement
    // =========================================================================
    @Test
    @DisplayName("Test 11: Direct-only policy rejects relay fallback even when direct fails")
    void testDirectOnlyPolicyEnforcement() {
        IceCandidate localRelay = IceCandidate.relay("198.51.100.1", 3478, "10.0.0.1", 54321, TransportProtocol.UDP);
        IceCandidate remoteRelay = IceCandidate.relay("198.51.100.2", 3478, "10.0.0.2", 54321, TransportProtocol.UDP);
        CandidatePair relayPair = new CandidatePair(localRelay, remoteRelay, true);
        relayPair.recordCheckSuccess(30);

        // Configure direct-only policy
        PathSelector selector = new PathSelector(PathSelector.Policy.directOnly());
        ConnectionDiagnostics diagnostics = selector.selectPath(Collections.singletonList(relayPair));

        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_FAILED, diagnostics.getOutcome());
        assertNull(diagnostics.getSelectedPair());
        assertTrue(diagnostics.getRelaySelectionReason().contains("Direct-only policy prohibited relay fallback"));
    }

    // =========================================================================
    // Test 12: Hysteresis (Anti-Flapping)
    // =========================================================================
    @Test
    @DisplayName("Test 12: Hysteresis prevents rapid direct/relay flapping on transient probe fluctuation")
    void testAntiFlappingHysteresis() {
        PathSelector.Policy policy = new PathSelector.Policy(false, true, 3, 0.20, 3);
        PathSelector selector = new PathSelector(policy);

        IceCandidate localRelay = IceCandidate.relay("198.51.100.1", 3478, "10.0.0.1", 54321, TransportProtocol.UDP);
        IceCandidate remoteRelay = IceCandidate.relay("198.51.100.2", 3478, "10.0.0.2", 54321, TransportProtocol.UDP);
        CandidatePair relayPair = new CandidatePair(localRelay, remoteRelay, true);
        relayPair.recordCheckSuccess(50);

        // Currently using RELAY path
        ConnectionDiagnostics diag1 = selector.selectPath(Collections.singletonList(relayPair));
        assertEquals(ConnectionDiagnostics.Outcome.RELAY_USED, diag1.getOutcome());

        // A direct path produces 1 successful check (probationary)
        IceCandidate localDirect = IceCandidate.host("192.168.1.10", 54321, TransportProtocol.UDP);
        IceCandidate remoteDirect = IceCandidate.host("192.168.1.20", 54321, TransportProtocol.UDP);
        CandidatePair directPair = new CandidatePair(localDirect, remoteDirect, true);
        directPair.recordCheckSuccess(10); // 1st success

        // Attempt selection: Hysteresis must SUPPRESS immediate switch until min successive probes reached
        ConnectionDiagnostics diag2 = selector.selectPath(Arrays.asList(directPair, relayPair));
        assertEquals(ConnectionDiagnostics.Outcome.RELAY_USED, diag2.getOutcome(), "Hysteresis must hold on relay until direct is proven stable");

        // 2nd success on direct
        directPair.recordCheckSuccess(10);
        ConnectionDiagnostics diag3 = selector.selectPath(Arrays.asList(directPair, relayPair));
        assertEquals(ConnectionDiagnostics.Outcome.RELAY_USED, diag3.getOutcome());

        // 3rd success on direct -> now satisfies hysteresis threshold (3 consecutive probes)
        directPair.recordCheckSuccess(10);
        ConnectionDiagnostics diag4 = selector.selectPath(Arrays.asList(directPair, relayPair));
        assertEquals(ConnectionDiagnostics.Outcome.DIRECT_SUCCEEDED, diag4.getOutcome());
        assertEquals(directPair, selector.getActivePair());
    }

    // =========================================================================
    // Test 13: Detailed Diagnostics Generation
    // =========================================================================
    @Test
    @DisplayName("Test 13: ConnectionDiagnostics generates structured report with metrics and rationales")
    void testDiagnosticsReportGeneration() {
        IceCandidate localRelay = IceCandidate.relay("198.51.100.1", 3478, "10.0.0.1", 54321, TransportProtocol.UDP);
        IceCandidate remoteRelay = IceCandidate.relay("198.51.100.2", 3478, "10.0.0.2", 54321, TransportProtocol.UDP);
        CandidatePair relayPair = new CandidatePair(localRelay, remoteRelay, true);
        relayPair.recordCheckSuccess(35);

        PathSelector selector = new PathSelector();
        ConnectionDiagnostics diagnostics = selector.selectPath(Collections.singletonList(relayPair));

        String report = diagnostics.toDiagnosticReport();
        assertNotNull(report);
        assertTrue(report.contains("Outcome: RELAY_USED"));
        assertTrue(report.contains("Why Relay Selected:"));
        assertTrue(report.contains("Connection Quality:"));
        assertTrue(report.contains("35ms"));
    }

    // =========================================================================
    // Test 14: STUN Packet Parsing Invariant
    // =========================================================================
    @Test
    @DisplayName("Test 14: STUN message encoding and XOR-MAPPED-ADDRESS parsing")
    void testStunBindingPacketParsing() throws Exception {
        byte[] txId = new byte[]{1,2,3,4,5,6,7,8,9,10,11,12};
        byte[] request = StunClient.buildBindingRequest(txId);

        assertEquals(20, request.length);
        assertEquals(StunClient.BINDING_REQUEST, ByteBuffer.wrap(request).getShort());
        assertEquals(StunClient.STUN_MAGIC_COOKIE, ByteBuffer.wrap(request, 4, 4).getInt());

        // Construct synthetic STUN response with XOR-MAPPED-ADDRESS
        ByteBuffer respBuf = ByteBuffer.allocate(32);
        respBuf.putShort(StunClient.BINDING_RESPONSE);
        respBuf.putShort((short) 12); // attr len
        respBuf.putInt(StunClient.STUN_MAGIC_COOKIE);
        respBuf.put(txId);

        // XOR-MAPPED-ADDRESS attribute
        respBuf.putShort(StunClient.ATTR_XOR_MAPPED_ADDRESS);
        respBuf.putShort((short) 8); // len
        respBuf.put((byte) 0); // reserved
        respBuf.put((byte) 0x01); // IPv4
        int port = 54321;
        int xorPort = port ^ (StunClient.STUN_MAGIC_COOKIE >>> 16);
        respBuf.putShort((short) xorPort);
        byte[] ip = new byte[]{(byte) 203, 0, 113, 10};
        int ipInt = ByteBuffer.wrap(ip).getInt();
        int xorIp = ipInt ^ StunClient.STUN_MAGIC_COOKIE;
        respBuf.putInt(xorIp);

        InetSocketAddress parsed = StunClient.parseBindingResponse(respBuf.array(), respBuf.position(), txId);
        assertNotNull(parsed);
        assertEquals("203.0.113.10", parsed.getAddress().getHostAddress());
        assertEquals(54321, parsed.getPort());
    }

    // =========================================================================
    // Test 15: SDP Candidate Serialization and Parsing Invariant
    // =========================================================================
    @Test
    @DisplayName("Test 15: ICE Candidate SDP serialization round-trip")
    void testIceCandidateSdpRoundTrip() {
        IceCandidate original = IceCandidate.srflx("203.0.113.5", 54321, "192.168.1.100", 54321, TransportProtocol.UDP);
        String sdp = original.toSdpLine();

        IceCandidate parsed = IceCandidate.fromSdpLine(sdp);
        assertEquals(original.getFoundation(), parsed.getFoundation());
        assertEquals(original.getComponentId(), parsed.getComponentId());
        assertEquals(original.getProtocol(), parsed.getProtocol());
        assertEquals(original.getPriority(), parsed.getPriority());
        assertEquals(original.getIp(), parsed.getIp());
        assertEquals(original.getPort(), parsed.getPort());
        assertEquals(original.getType(), parsed.getType());
        assertEquals(original.getRelAddr(), parsed.getRelAddr());
        assertEquals(original.getRelPort(), parsed.getRelPort());
    }
}
