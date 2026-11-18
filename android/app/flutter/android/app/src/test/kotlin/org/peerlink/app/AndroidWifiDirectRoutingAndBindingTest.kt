package org.peerlink.app

import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pInfo
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.peerlink.app.discovery.AndroidWifiDirectAdapter
import org.peerlink.core.android.discovery.*
import org.peerlink.core.security.InMemoryTrustStore
import org.peerlink.core.security.PeerCryptoSigner
import org.peerlink.core.transport.*
import org.peerlink.protocol.v1.*
import java.io.IOException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

/**
 * Phase 12.7 Regression Test Suite:
 * Wi-Fi Direct Routing, Dynamic Role Resolution, Socket Binding & Full-Duplex Session Recovery.
 */
class AndroidWifiDirectRoutingAndBindingTest {

    private lateinit var adapter: AndroidWifiDirectAdapter
    private val discoveredRecords = CopyOnWriteArrayList<DiscoveredPeerRecord>()
    private val lostPeers = CopyOnWriteArrayList<PeerId>()
    private val invalidatedTechnologies = CopyOnWriteArrayList<String>()

    private val callback = object : DiscoveryAdapter.DiscoveryCallback {
        override fun onPeerFound(peer: DiscoveredPeerRecord) {
            discoveredRecords.add(peer)
        }

        override fun onPeerLost(peerId: PeerId) {
            lostPeers.add(peerId)
        }

        override fun onDiscoveryError(technology: String, errorMessage: String) {}

        override fun onRoutesInvalidated(technology: String) {
            invalidatedTechnologies.add(technology)
        }
    }

    @Before
    fun setUp() {
        adapter = AndroidWifiDirectAdapter(null, true) { 8765 }
        adapter.permissionChecker = { true }
    }

    @Test
    fun testHandlePeersChangedEmitsNoHardcoded192Address() {
        adapter.startDiscovery(callback)

        val device = WifiP2pDevice().apply {
            deviceName = "moto g86 power 5G_2IBs"
            deviceAddress = "b2:cc:61:d1:93:aa"
        }

        adapter.handleDiscoveredDevices(listOf(device))

        assertEquals("Must discover 1 peer", 1, discoveredRecords.size)
        val discovered = discoveredRecords[0]
        assertEquals("moto g86 power 5G_2IBs", discovered.displayName)
        assertEquals("p2p_b2cc61d193aa", discovered.peerId.value)

        // Critical Rule 3 verification: NO hardcoded route emitted!
        assertTrue("Discovered peer must have NO routes before group forms", discovered.availableRoutes.isEmpty())
        assertEquals("Host address must be empty", "", discovered.hostAddress)
        assertEquals("Port must be 0", 0, discovered.port)
        assertNotEquals("Must NEVER fabricate 192.168.49.1", "192.168.49.1", discovered.hostAddress)
    }

    @Test
    fun testGroupFormationAsClientPublishesRemoteOwnerRoute() {
        adapter.startDiscovery(callback)

        val info = WifiP2pInfo().apply {
            groupFormed = true
            isGroupOwner = false
            groupOwnerAddress = InetAddress.getByName("192.168.49.1")
        }

        val ownerDevice = WifiP2pDevice().apply {
            deviceName = "PeerLink Group Owner"
            deviceAddress = "aa:bb:cc:dd:ee:ff"
        }

        adapter.handleConnectionChanged(info, "p2p-wlan0-0", ownerDevice)

        assertTrue("Must publish route for group owner", discoveredRecords.isNotEmpty())
        val ownerRecord = discoveredRecords.find { it.peerId.value == "p2p_aabbccddeeff" }
        assertNotNull("Owner record must exist", ownerRecord)
        assertEquals("192.168.49.1", ownerRecord!!.hostAddress)
        assertEquals(8765, ownerRecord.port)

        val bestRoute = ownerRecord.bestRoute
        assertNotNull(bestRoute)
        assertEquals("WIFI_DIRECT", bestRoute.discoveryTechnology)
        assertEquals("192.168.49.1", bestRoute.hostAddress)
        assertEquals(8765, bestRoute.port)
        assertFalse("Local device is client, not group owner", bestRoute.isGroupOwner)
        assertNotNull("PreConnectSocketBinder must be attached", bestRoute.socketBinder)
        assertEquals(1L, bestRoute.generation)
    }

    @Test
    fun testGroupFormationAsGroupOwnerDoesNotPublishRouteToSelf() {
        adapter.startDiscovery(callback)

        val info = WifiP2pInfo().apply {
            groupFormed = true
            isGroupOwner = true
            groupOwnerAddress = InetAddress.getByName("192.168.49.1")
        }

        val ownerDevice = WifiP2pDevice().apply {
            deviceName = "Local Device GO"
            deviceAddress = "11:22:33:44:55:66"
        }
        val client = WifiP2pDevice().apply {
            deviceName = "Remote Client Phone"
            deviceAddress = "77:88:99:aa:bb:cc"
        }

        adapter.handleConnectionChanged(info, "p2p-wlan0-0", ownerDevice, listOf(client))

        // As group owner, local device's IP is 192.168.49.1.
        // It must NOT advertise an outbound route targeting itself!
        for (record in discoveredRecords) {
            for (route in record.availableRoutes) {
                assertNotEquals("Group Owner must NEVER publish outbound route to its own IP",
                    "192.168.49.1", route.hostAddress)
            }
        }

        // Client device should be discovered so UI sees it
        val clientRecord = discoveredRecords.find { it.peerId.value == "p2p_778899aabbcc" }
        assertNotNull("Client record should be discovered", clientRecord)
        assertTrue("Client must have no outbound routes from group owner", clientRecord!!.availableRoutes.isEmpty())
    }

    @Test
    fun testDisconnectionInvalidatesRoutes() {
        adapter.startDiscovery(callback)

        val info = WifiP2pInfo().apply {
            groupFormed = true
            isGroupOwner = false
            groupOwnerAddress = InetAddress.getByName("192.168.49.1")
        }
        adapter.handleConnectionChanged(info, "p2p-wlan0-0", null)
        assertEquals(1, adapter.currentGroupGeneration)

        // Now disconnect
        adapter.handleDisconnected()

        assertEquals(2, adapter.currentGroupGeneration)
        assertNull(adapter.lastWifiP2pInfo)
        assertNull(adapter.lastInterfaceName)
        assertTrue("Must notify routes invalidated for WIFI_DIRECT",
            invalidatedTechnologies.contains("WIFI_DIRECT"))
    }

    @Test
    fun testSocketBinderThrowsExplicitExceptionWhenNetworkUnavailable() {
        // Without active Wi-Fi Direct network or interface, binder must fail explicitly
        val binder = adapter.createSocketBinder("non_existent_p2p_iface")

        val socket = Socket()
        try {
            binder.bind(socket)
            fail("Expected IOException when no Wi-Fi Direct network is available")
        } catch (e: IOException) {
            assertTrue("Error must explain WIFI_DIRECT_NETWORK_UNAVAILABLE: " + e.message,
                e.message?.contains("WIFI_DIRECT_NETWORK_UNAVAILABLE") == true)
        } finally {
            socket.close()
        }
    }

    @Test
    fun testSocketBinderInvokesCustomBindingHook() {
        var boundInterface: String? = null
        val binderInvoked = AtomicBoolean(false)

        adapter.customSocketBinder = { _, iface ->
            binderInvoked.set(true)
            boundInterface = iface
        }

        val binder = adapter.createSocketBinder("p2p-wlan0-0")
        val socket = Socket()
        binder.bind(socket)
        socket.close()

        assertTrue("Custom binder hook must be executed", binderInvoked.get())
        assertEquals("p2p-wlan0-0", boundInterface)
    }

    @Test
    fun testRouteSelectorPassesSocketBinderToTransportProvider() {
        var capturedBinder: PreConnectSocketBinder? = null
        var capturedAddress: InetSocketAddress? = null

        val mockProvider = object : TransportProvider {
            override fun getTransportType(): TransportType = TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS
            override fun isAvailable(): Boolean = true
            override fun getPriority(): Int = 1
            override fun startListening(port: Int, listener: TransportConnectionListener?) {}
            override fun getListeningPort(): Int = 8765
            override fun stopListening() {}
            override fun close() {}

            override fun connectAsync(remoteAddress: InetSocketAddress, socketBinder: PreConnectSocketBinder?): CompletableFuture<TransportConnection> {
                capturedAddress = remoteAddress
                capturedBinder = socketBinder
                return CompletableFuture.completedFuture(createDummyConnection(remoteAddress))
            }

            override fun connectAsync(remoteAddress: InetSocketAddress): CompletableFuture<TransportConnection> {
                return connectAsync(remoteAddress, null)
            }
        }

        val binderRan = AtomicBoolean(false)
        val testBinder = PreConnectSocketBinder { _ -> binderRan.set(true) }

        val route = PeerTransportRoute(
            "192.168.49.1",
            8765,
            "WIFI_DIRECT",
            listOf("TCP_TLS"),
            100,
            testBinder,
            1L,
            false
        )

        val peerRecord = DiscoveredPeerRecord(
            PeerId.newBuilder().setValue("p2p_target_client").build(),
            "Target Peer",
            "WIFI_DIRECT"
        )
        peerRecord.addOrMergeRoute(route)

        val selector = TransportRouteSelector(mockProvider, 1000L)
        val result = selector.connectWithFallbackAsync(peerRecord).get()

        assertNotNull(result)
        assertEquals("192.168.49.1", capturedAddress?.hostString)
        assertEquals(8765, capturedAddress?.port)
        assertSame("Route selector must pass route's socketBinder", testBinder, capturedBinder)
    }

    @Test
    fun testPeerSessionManagerAliasAndProvisionalPairing() {
        val trustStore = InMemoryTrustStore()
        val signer = PeerCryptoSigner.generate("key_test")
        val localPeer = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue("local_peer_001").build())
            .setIdentityKey(signer.toProtobufKey(System.currentTimeMillis()))
            .setTrustLevel(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED)
            .build()
        val localDevice = DeviceIdentity.newBuilder().setDeviceId(DeviceId.newBuilder().setValue("dev_001").build()).build()
        val version = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build()

        val sessionManager = PeerSessionManager(
            localPeer,
            localDevice,
            signer,
            trustStore,
            version,
            version,
            TransportCapabilityNegotiator(emptyList())
        )

        // Pre-pair provisional peer ID in trust store (as occurs in UI)
        trustStore.addTrustedPeer("p2p_b2cc61d193aa", "moto g86 power", ByteArray(32))
        assertTrue(trustStore.isTrusted("p2p_b2cc61d193aa"))

        // Register alias for authentic peer identity
        val authenticPeerId = "peer_ed25519_verified_moto"
        sessionManager.registerPeerAlias("p2p_b2cc61d193aa", authenticPeerId)

        // Session lookup by provisional ID should resolve to canonical
        val resolvedSession = sessionManager.getSessionByPeerId("p2p_b2cc61d193aa")
        // No active session registered yet, so empty, but no crash
        assertFalse(resolvedSession.isPresent)
    }

    @Test
    fun testDynamicNon192SubnetGroupOwnerRoutePublication() {
        adapter.startDiscovery(callback)

        val dynamicIp = "192.168.43.1"
        val info = WifiP2pInfo().apply {
            groupFormed = true
            isGroupOwner = false
            groupOwnerAddress = InetAddress.getByName(dynamicIp)
        }

        val ownerDevice = WifiP2pDevice().apply {
            deviceName = "Dynamic Subnet Group Owner"
            deviceAddress = "11:22:33:44:55:66"
        }

        adapter.handleConnectionChanged(info, "p2p-wlan0-0", ownerDevice)

        val ownerRecord = discoveredRecords.find { it.peerId.value == "p2p_112233445566" }
        assertNotNull("Owner record must exist for non-192.168.49 group owner", ownerRecord)
        assertEquals("Route must publish dynamic IP $dynamicIp", dynamicIp, ownerRecord!!.hostAddress)
        assertEquals(8765, ownerRecord.port)

        var binderInvoked = false
        adapter.customSocketBinder = { sock, iface ->
            binderInvoked = true
            assertEquals("p2p-wlan0-0", iface)
        }

        val bestRoute = ownerRecord.availableRoutes[0]
        val socket = Socket()
        bestRoute.socketBinder.bind(socket)
        assertTrue("Custom socket binder must be invoked on unconnected socket", binderInvoked)
    }

    @Test
    fun testNetworkCandidateRejectsCellularTransportEvenWithMatchingSubnet() {
        val attrs = AndroidWifiDirectAdapter.NetworkAttributes(
            interfaceName = "rmnet_data0",
            hasCellular = true
        )

        val result = adapter.isNetworkCandidateForWifiDirect("p2p-wlan0-0", attrs, "192.168.49.")
        assertFalse("Cellular transport must NEVER be selected as Wi-Fi Direct network", result)
    }

    @Test
    fun testNetworkCandidateRejectsWlan0StationModeMisleadingAddress() {
        val attrs = AndroidWifiDirectAdapter.NetworkAttributes(
            interfaceName = "wlan0", // Station mode!
            hasCellular = false,
            hasBluetooth = false,
            hasEthernet = false,
            hasWifiP2pCapability = false
        )

        val result = adapter.isNetworkCandidateForWifiDirect("p2p-wlan0-0", attrs, "192.168.49.")
        assertFalse("wlan0 station mode must NOT be accepted merely due to IP subnet match", result)
    }

    @Test
    fun testNetworkCandidateAcceptsExactInterfaceMatch() {
        val attrs = AndroidWifiDirectAdapter.NetworkAttributes(
            interfaceName = "p2p-wlan0-0"
        )

        val result = adapter.isNetworkCandidateForWifiDirect("p2p-wlan0-0", attrs, "192.168.49.")
        assertTrue("Exact matching P2P interface must be accepted", result)
    }

    @Test
    fun testNetworkCandidateAcceptsP2pCapability() {
        val attrs = AndroidWifiDirectAdapter.NetworkAttributes(
            interfaceName = "p2p-custom-0",
            hasWifiP2pCapability = true
        )

        val result = adapter.isNetworkCandidateForWifiDirect(null, attrs, "192.168.43.")
        assertTrue("NET_CAPABILITY_WIFI_P2P must be accepted", result)
    }

    @Test
    fun testNetworkCandidateAcceptsP2pInterfaceNaming() {
        val attrs = AndroidWifiDirectAdapter.NetworkAttributes(
            interfaceName = "p2p-wlan0-1"
        )

        val result = adapter.isNetworkCandidateForWifiDirect(null, attrs, "172.16.49.")
        assertTrue("P2P interface naming prefix must be accepted", result)
    }

    private fun createDummyConnection(addr: InetSocketAddress): TransportConnection {
        return object : TransportConnection {
            override fun getConnectionId(): ConnectionId = ConnectionId.newBuilder().setValue("conn_dummy").build()
            override fun getTransportType(): TransportType = TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS
            override fun getState(): ConnectionState = ConnectionState.CONNECTED
            override fun getRemoteAddress(): InetSocketAddress = addr
            override fun getLocalAddress(): InetSocketAddress = InetSocketAddress("127.0.0.1", 8765)
            override fun sendFrameAsync(frame: TransportFrame): CompletableFuture<Void> = CompletableFuture.completedFuture(null)
            override fun setFrameHandler(handler: TransportFrameHandler?) {}
            override fun addLifecycleListener(listener: ConnectionLifecycleListener?) {}
            override fun closeAsync(): CompletableFuture<Void> = CompletableFuture.completedFuture(null)
            override fun close() {}
        }
    }
}
