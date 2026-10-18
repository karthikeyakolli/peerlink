package org.peerlink.app

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.peerlink.core.android.discovery.*
import org.peerlink.core.transport.*
import org.peerlink.protocol.v1.ConnectionId
import org.peerlink.protocol.v1.PeerId
import org.peerlink.protocol.v1.TransportType
import java.io.IOException
import java.net.InetSocketAddress
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Phase 4 Acceptance Gate: Automatic Nearby Discovery & Transport Selection.
 *
 * Verifies:
 * 1. Self-filtering: local device is never shown as a discovered remote peer.
 * 2. Multi-technology deduplication & route merging: multiple discovery sources for the same peer
 *    are merged into a single deduplicated record with multiple prioritized routes.
 * 3. Stale peer expiration: peers not seen within TTL are pruned and trigger onPeerLost.
 * 4. Manual endpoint addition: fallback route can be added explicitly when multicast/mDNS is blocked.
 * 5. Transport abstraction & sequential fallback: when high-priority route fails, TransportRouteSelector
 *    automatically falls back to the next candidate route without exposing radio logic.
 * 6. Connection state tracking: unauthenticated advertisements are clearly distinguished from connected peers.
 */
class AndroidDiscoveryAndTransportSelectionTest {

    private lateinit var localPeerId: PeerId
    private lateinit var engine: AndroidDiscoveryEngine
    private val discoveredEvents = CopyOnWriteArrayList<DiscoveredPeerRecord>()
    private val lostEvents = CopyOnWriteArrayList<PeerId>()

    @Before
    fun setUp() {
        localPeerId = PeerId.newBuilder().setValue("local_pixel9_owner").build()
        engine = AndroidDiscoveryEngine(emptyList())
        engine.localPeerId = localPeerId

        engine.addListener(object : AndroidDiscoveryEngine.EngineListener {
            override fun onPeerDiscovered(peer: DiscoveredPeerRecord) {
                discoveredEvents.add(peer)
            }

            override fun onPeerLost(peerId: PeerId) {
                lostEvents.add(peerId)
            }
        })
    }

    @Test
    fun testSelfFilteringIgnoresLocalDevice() {
        val selfRecord = DiscoveredPeerRecord(
            localPeerId,
            "Local Pixel 9",
            "192.168.1.15",
            8765,
            "NSD_MDNS",
            listOf("TCP_TLS")
        )

        engine.onPeerFound(selfRecord)

        assertTrue("Engine must ignore self discovery record", engine.activePeers.isEmpty())
        assertTrue("No discovery events should fire for self", discoveredEvents.isEmpty())
    }

    @Test
    fun testPeerDeduplicationAndMultiRouteAggregation() {
        val remotePeerId = PeerId.newBuilder().setValue("peer_desktop_work").build()

        // 1. Peer discovered via NSD / mDNS on local Wi-Fi
        val nsdRecord = DiscoveredPeerRecord(
            remotePeerId,
            "Workstation PC",
            "192.168.1.50",
            8765,
            "NSD_MDNS",
            listOf("QUIC", "TCP_TLS")
        )
        engine.onPeerFound(nsdRecord)

        assertEquals(1, engine.activePeers.size)
        val active = engine.activePeers[remotePeerId]!!
        assertEquals("Workstation PC", active.displayName)
        assertEquals("192.168.1.50", active.hostAddress)
        assertEquals(8765, active.port)
        assertEquals(1, active.availableRoutes.size)
        assertTrue(active.discoveryTechnologies.contains("NSD_MDNS"))

        // 2. Same peer discovered via Wi-Fi Direct on P2P interface
        val wifiDirectRecord = DiscoveredPeerRecord(
            remotePeerId,
            "Workstation PC",
            "192.168.49.2",
            8765,
            "WIFI_DIRECT",
            listOf("TCP_TLS")
        )
        engine.onPeerFound(wifiDirectRecord)

        // Must remain deduplicated to a single peer record
        assertEquals("Must remain deduplicated to 1 peer", 1, engine.activePeers.size)
        val merged = engine.activePeers[remotePeerId]!!
        assertEquals("Workstation PC", merged.displayName)
        assertEquals("Must aggregate 2 routes", 2, merged.availableRoutes.size)
        assertTrue(merged.discoveryTechnologies.contains("NSD_MDNS"))
        assertTrue(merged.discoveryTechnologies.contains("WIFI_DIRECT"))

        // Best route must prioritize NSD (Priority 1) over Wi-Fi Direct (Priority 2)
        assertEquals("192.168.1.50", merged.hostAddress)
        assertEquals(1, merged.bestRoute.priority)
    }

    @Test
    fun testStalePeerPruningAndExpiration() {
        val remotePeerId = PeerId.newBuilder().setValue("peer_transient_visitor").build()
        val record = DiscoveredPeerRecord(
            remotePeerId,
            "Visitor Phone",
            "192.168.1.99",
            8765,
            "NSD_MDNS",
            listOf("TCP_TLS")
        )
        engine.onPeerFound(record)
        assertEquals(1, engine.activePeers.size)

        // Sweep with maxAge 0 ms (forces immediate expiration)
        val pruned = engine.sweepStalePeers(0)

        assertEquals(1, pruned.size)
        assertEquals(remotePeerId, pruned[0])
        assertTrue("Active peers must be empty after pruning", engine.activePeers.isEmpty())
        assertEquals("Lost event must fire for expired peer", 1, lostEvents.size)
        assertEquals(remotePeerId, lostEvents[0])
    }

    @Test
    fun testManualEndpointAdditionAsFallbackRoute() {
        val manualPeerId = PeerId.newBuilder().setValue("peer_isolated_server").build()

        val record = engine.addManualPeer(manualPeerId, "Isolated Lab Server", "10.0.0.42", 9000)

        assertNotNull(record)
        assertEquals("Isolated Lab Server", record.displayName)
        assertEquals("10.0.0.42", record.hostAddress)
        assertEquals(9000, record.port)
        assertTrue(record.discoveryTechnologies.contains("MANUAL"))
        assertEquals(1, engine.activePeers.size)
        assertEquals(1, discoveredEvents.size)
    }

    @Test
    fun testTransportRouteSelectorSequentialFallback() {
        val remotePeerId = PeerId.newBuilder().setValue("peer_multi_route_target").build()
        val peer = DiscoveredPeerRecord(
            remotePeerId,
            "Multi-Route Target",
            "192.168.1.200", // Route 1: fails
            8765,
            "NSD_MDNS",
            listOf("TCP_TLS")
        )
        // Route 2: Wi-Fi Direct secondary route (succeeds)
        val route2 = PeerTransportRoute(
            "192.168.49.5",
            8765,
            "WIFI_DIRECT",
            listOf("TCP_TLS"),
            2
        )
        peer.addOrMergeRoute(route2)

        val connectedAddresses = mutableListOf<String>()

        // Mock transport provider failing on 192.168.1.200 and succeeding on 192.168.49.5
        val transportProvider = object : TransportProvider {
            override fun getTransportType(): TransportType = TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS
            override fun isAvailable(): Boolean = true
            override fun getPriority(): Int = 1
            override fun startListening(port: Int, listener: TransportConnectionListener?) {}
            override fun getListeningPort(): Int = 8765
            override fun stopListening() {}
            override fun close() {}

            override fun connectAsync(remoteAddress: InetSocketAddress): CompletableFuture<TransportConnection> {
                connectedAddresses.add(remoteAddress.hostString)
                if (remoteAddress.hostString == "192.168.1.200") {
                    return CompletableFuture.failedFuture(IOException("Connection refused on LAN IP"))
                }
                val mockConn = object : TransportConnection {
                    override fun getConnectionId(): ConnectionId = ConnectionId.newBuilder().setValue("conn_test_01").build()
                    override fun getTransportType(): TransportType = TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS
                    override fun getState(): ConnectionState = ConnectionState.CONNECTED
                    override fun getRemoteAddress(): InetSocketAddress = remoteAddress
                    override fun getLocalAddress(): InetSocketAddress = InetSocketAddress("127.0.0.1", 8765)
                    override fun sendFrameAsync(frame: org.peerlink.protocol.v1.TransportFrame): CompletableFuture<Void> = CompletableFuture.completedFuture(null)
                    override fun setFrameHandler(handler: TransportFrameHandler?) {}
                    override fun addLifecycleListener(listener: ConnectionLifecycleListener?) {}
                    override fun closeAsync(): CompletableFuture<Void> = CompletableFuture.completedFuture(null)
                    override fun close() {}
                }
                return CompletableFuture.completedFuture(mockConn)
            }
        }

        val selector = TransportRouteSelector(transportProvider, 1000L)
        val result = selector.connectWithFallbackAsync(peer).get()

        assertNotNull(result)
        assertTrue("Selector must indicate fallback occurred", result.didFallback)
        assertEquals("192.168.49.5", result.chosenRoute.hostAddress)
        assertEquals("WIFI_DIRECT", result.chosenRoute.discoveryTechnology)
        assertEquals(2, connectedAddresses.size)
        assertEquals("192.168.1.200", connectedAddresses[0])
        assertEquals("192.168.49.5", connectedAddresses[1])
    }

    @Test
    fun testPeerConnectionStateDistinguishesDiscoveredFromConnected() {
        val remotePeerId = PeerId.newBuilder().setValue("peer_state_check").build()
        val record = DiscoveredPeerRecord(
            remotePeerId,
            "State Check Peer",
            "192.168.1.77",
            8765,
            "NSD_MDNS",
            listOf("TCP_TLS")
        )
        engine.onPeerFound(record)

        assertEquals(PeerConnectionState.DISCOVERED, record.connectionState)
        assertEquals(1, engine.discoveredPeers.size)
        assertEquals(0, engine.connectedPeers.size)

        // Authenticated connection established
        engine.updatePeerConnectionState(remotePeerId, PeerConnectionState.AUTHENTICATED_CONNECTED)

        assertEquals(PeerConnectionState.AUTHENTICATED_CONNECTED, record.connectionState)
        assertEquals(1, engine.connectedPeers.size)
    }
}
