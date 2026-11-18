package org.peerlink.app.discovery

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.net.NetworkInfo
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pDeviceList
import android.net.wifi.p2p.WifiP2pGroup
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import org.peerlink.core.android.discovery.PeerTransportRoute
import org.peerlink.core.android.discovery.WifiDirectDiscoveryAdapter
import org.peerlink.core.android.discovery.DiscoveryAdapter.DiscoveryCallback
import org.peerlink.core.transport.PreConnectSocketBinder
import org.peerlink.protocol.v1.PeerId
import org.slf4j.LoggerFactory
import java.io.IOException
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

/**
 * Android platform WifiP2pManager implementation bridging to WifiDirectDiscoveryAdapter.
 * Handles permission validation, peer broadcast reception, dynamic group/role resolution,
 * network-aware socket binding, and route lifecycle.
 */
class AndroidWifiDirectAdapter(
    private val context: Context? = null,
    isAvailableOverride: Boolean? = null,
    private val listeningPortProvider: () -> Int = { 8765 }
) : WifiDirectDiscoveryAdapter(
    isAvailableOverride ?: (try {
        context?.packageManager?.hasSystemFeature(android.content.pm.PackageManager.FEATURE_WIFI_DIRECT) ?: true
    } catch (t: Throwable) { true })
) {
    companion object {
        private val log = LoggerFactory.getLogger(AndroidWifiDirectAdapter::class.java)
    }

    private val p2pManager: WifiP2pManager? = try {
        context?.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    } catch (t: Throwable) { null }

    private val channel: WifiP2pManager.Channel? = try {
        if (context != null && p2pManager != null) {
            p2pManager.initialize(context, context.mainLooper, null)
        } else null
    } catch (t: Throwable) { null }

    private var peerBroadcastReceiver: BroadcastReceiver? = null
    private var lastCallback: DiscoveryCallback? = null

    // Track active connection state and group generation
    internal var lastWifiP2pInfo: WifiP2pInfo? = null
        private set
    internal var lastInterfaceName: String? = null
        private set
    internal var lastOwnerDevice: WifiP2pDevice? = null
        private set
    internal var lastClientDevices: Collection<WifiP2pDevice>? = null
        private set
    internal var currentGroupGeneration: Int = 0
        private set

    // Discovered devices cache to update when group forms
    private val discoveredDevices = ConcurrentHashMap<String, DiscoveredDeviceEntry>()

    data class DiscoveredDeviceEntry(val peerId: PeerId, val name: String, val deviceAddress: String)

    /**
     * Optional permission checker hook for testing permission grant/denial/revocation.
     */
    var permissionChecker: ((Context?) -> Boolean)? = null

    /**
     * Optional network binder override hook for testing socket binding without real hardware.
     */
    var customSocketBinder: ((Socket, String?) -> Unit)? = null

    fun hasNearbyWifiPermission(): Boolean {
        permissionChecker?.let { return it(context) }
        val ctx = context ?: return true
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.checkSelfPermission(android.Manifest.permission.NEARBY_WIFI_DEVICES) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ctx.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
        } else true
    }

    override fun startDiscovery(callback: DiscoveryCallback) {
        lastCallback = callback
        if (!isAvailable) {
            callback.onDiscoveryError(technologyName, "Wi-Fi Direct is not supported on this device")
            return
        }
        if (!hasNearbyWifiPermission()) {
            callback.onDiscoveryError(technologyName, "PERMISSION_DENIED: Nearby Wi-Fi devices permission required")
            return
        }

        super.startDiscovery(callback)

        registerPeerReceiver()

        if (p2pManager != null && channel != null) {
            try {
                p2pManager.discoverPeers(channel, object : WifiP2pManager.ActionListener {
                    override fun onSuccess() {
                        log.info("Wi-Fi Direct discoverPeers succeeded")
                    }
                    override fun onFailure(reasonCode: Int) {
                        callback.onDiscoveryError(technologyName, "Wi-Fi Direct peer discovery failed with code $reasonCode")
                    }
                })
            } catch (se: SecurityException) {
                callback.onDiscoveryError(technologyName, "SecurityException: " + se.message)
            }
        }
    }

    private fun registerPeerReceiver() {
        val ctx = context ?: return
        if (peerBroadcastReceiver == null && p2pManager != null && channel != null) {
            val filter = IntentFilter().apply {
                addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
            }
            peerBroadcastReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, intent: Intent?) {
                    when (intent?.action) {
                        WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                            val state = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1)
                            if (state == WifiP2pManager.WIFI_P2P_STATE_DISABLED) {
                                log.warn("Wi-Fi Direct was disabled on device; invalidating routes")
                                handleDisconnected()
                            }
                        }
                        WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                            try {
                                p2pManager.requestPeers(channel) { deviceList: WifiP2pDeviceList? ->
                                    handlePeersChanged(deviceList)
                                }
                            } catch (ignored: SecurityException) {}
                        }
                        WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                            @Suppress("DEPRECATION")
                            val networkInfo = intent.getParcelableExtra<NetworkInfo>(WifiP2pManager.EXTRA_NETWORK_INFO)
                            if (networkInfo?.isConnected == true) {
                                try {
                                    p2pManager.requestConnectionInfo(channel) { info ->
                                        try {
                                            p2pManager.requestGroupInfo(channel) { group ->
                                                handleConnectionChanged(info, group)
                                            }
                                        } catch (e: Exception) {
                                            handleConnectionChanged(info, null)
                                        }
                                    }
                                } catch (ignored: SecurityException) {}
                            } else {
                                handleDisconnected()
                            }
                        }
                        WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION -> {
                            @Suppress("DEPRECATION")
                            val device = intent.getParcelableExtra<WifiP2pDevice>(WifiP2pManager.EXTRA_WIFI_P2P_DEVICE)
                            log.debug("This Wi-Fi Direct device updated: {} ({}) status={}",
                                device?.deviceName, device?.deviceAddress, device?.status)
                        }
                    }
                }
            }
            try {
                ctx.registerReceiver(peerBroadcastReceiver, filter)
            } catch (e: Exception) {
                log.error("Failed to register Wi-Fi Direct BroadcastReceiver", e)
            }
        }
    }

    /**
     * Handles peer discovery scan results.
     * Rule 3: Only registers provisional discovered peers. NEVER publishes a fabricated IP route!
     */
    internal fun handlePeersChanged(deviceList: WifiP2pDeviceList?) {
        if (!isDiscovering) return
        handleDiscoveredDevices(deviceList?.deviceList)
    }

    internal fun handleDiscoveredDevices(devices: Collection<WifiP2pDevice>?) {
        if (devices == null || !isDiscovering) return
        for (device in devices) {
            val address = device.deviceAddress ?: continue
            val peerIdStr = "p2p_" + address.replace(":", "").lowercase()
            val peerId = PeerId.newBuilder().setValue(peerIdStr).build()
            val name = if (!device.deviceName.isNullOrBlank()) device.deviceName else "Wi-Fi Direct Peer"
            discoveredDevices[address] = DiscoveredDeviceEntry(peerId, name, address)
            // Register discovered peer with no IP routes until group formation!
            notifyPeerDiscovered(peerId, name)
        }
        // If a group is currently active, refresh route for applicable peers
        lastWifiP2pInfo?.let { updateRoutesForGroup(it, lastInterfaceName, lastOwnerDevice, lastClientDevices) }
    }

    /**
     * Handles dynamic Wi-Fi Direct connection changes (group formed/dissolved, role determined).
     */
    internal fun handleConnectionChanged(info: WifiP2pInfo?, group: WifiP2pGroup?) {
        handleConnectionChanged(info, group?.`interface`, group?.owner, group?.clientList)
    }

    internal fun handleConnectionChanged(
        info: WifiP2pInfo?,
        interfaceName: String?,
        ownerDevice: WifiP2pDevice?,
        clientDevices: Collection<WifiP2pDevice>? = null
    ) {
        lastWifiP2pInfo = info
        lastInterfaceName = interfaceName
        lastOwnerDevice = ownerDevice
        lastClientDevices = clientDevices

        if (info == null || !info.groupFormed) {
            handleDisconnected()
            return
        }

        currentGroupGeneration++
        log.info("Wi-Fi Direct group formed [gen={}]: isGroupOwner={}, groupOwnerAddress={}",
            currentGroupGeneration, info.isGroupOwner, info.groupOwnerAddress?.hostAddress)

        updateRoutesForGroup(info, interfaceName, ownerDevice, clientDevices)
    }

    /**
     * Disconnection cleanup: invalidates stale routes and increments group generation.
     */
    internal fun handleDisconnected() {
        log.info("Wi-Fi Direct group dissolved or disconnected; clearing routes")
        currentGroupGeneration++
        lastWifiP2pInfo = null
        lastInterfaceName = null
        lastOwnerDevice = null
        lastClientDevices = null
        notifyRoutesInvalidated()
    }

    /**
     * Role-aware route construction:
     * - Client: Connects to remote group owner's address with network-bound socket.
     * - Group Owner: Never targets own address; awaits incoming client session on bound port.
     */
    private fun updateRoutesForGroup(
        info: WifiP2pInfo,
        ifaceName: String?,
        ownerDevice: WifiP2pDevice?,
        clientDevices: Collection<WifiP2pDevice>?
    ) {
        if (!info.groupFormed) return

        val targetPort = listeningPortProvider()

        if (!info.isGroupOwner) {
            // Local device is GROUP CLIENT
            val goAddress = info.groupOwnerAddress?.hostAddress
            if (goAddress.isNullOrBlank() || goAddress == "0.0.0.0") {
                log.warn("Wi-Fi Direct group client has invalid groupOwnerAddress: {}", goAddress)
                return
            }

            val socketBinder = createSocketBinder(ifaceName)
            val route = PeerTransportRoute(
                goAddress,
                targetPort,
                technologyName,
                listOf("TCP_TLS", "QUIC"),
                100,
                socketBinder,
                currentGroupGeneration.toLong(),
                false
            )

            // Resolve group owner identity
            val ownerPeerId: PeerId
            val ownerName: String
            if (ownerDevice != null && !ownerDevice.deviceAddress.isNullOrBlank()) {
                val p2pId = "p2p_" + ownerDevice.deviceAddress.replace(":", "").lowercase()
                ownerPeerId = PeerId.newBuilder().setValue(p2pId).build()
                ownerName = if (!ownerDevice.deviceName.isNullOrBlank()) ownerDevice.deviceName else "Wi-Fi Direct Group Owner"
            } else {
                ownerPeerId = PeerId.newBuilder().setValue("p2p_go_" + goAddress.replace(".", "_")).build()
                ownerName = "Wi-Fi Direct Group Owner"
            }

            log.info("Publishing Wi-Fi Direct route for Group Owner [{}]: {} -> {}:{} (iface={}, gen={})",
                ownerPeerId.value, ownerName, goAddress, targetPort, ifaceName, currentGroupGeneration)
            notifyRouteUpdated(ownerPeerId, ownerName, route)

            // Also attach the route to any discovered device entries that match the group owner
            for (entry in discoveredDevices.values) {
                if (ownerDevice != null && entry.deviceAddress.equals(ownerDevice.deviceAddress, ignoreCase = true)) {
                    notifyRouteUpdated(entry.peerId, entry.name, route)
                }
            }
        } else {
            // Local device is GROUP OWNER
            // info.groupOwnerAddress is OUR OWN IP! NEVER advertise an outbound route to ourselves!
            log.info("Local device is Wi-Fi Direct Group Owner on iface {} (port={}). Ready for incoming client connections.",
                ifaceName, targetPort)

            // Register discovered group clients so UI can display them, but without outbound routes
            if (clientDevices != null) {
                for (client in clientDevices) {
                    val address = client.deviceAddress ?: continue
                    val peerIdStr = "p2p_" + address.replace(":", "").lowercase()
                    val peerId = PeerId.newBuilder().setValue(peerIdStr).build()
                    val name = if (!client.deviceName.isNullOrBlank()) client.deviceName else "Wi-Fi Direct Client"
                    discoveredDevices[address] = DiscoveredDeviceEntry(peerId, name, address)
                    notifyPeerDiscovered(peerId, name)
                }
            }
        }
    }

    /**
     * Creates a PreConnectSocketBinder that binds an unconnected client socket to the Wi-Fi Direct path.
     */
    internal fun createSocketBinder(interfaceName: String?): PreConnectSocketBinder {
        return PreConnectSocketBinder { socket ->
            bindSocketToWifiDirect(socket, interfaceName)
        }
    }

    /**
     * Network-aware socket binding strategy (Rule 4):
     * 1. Bind to Android ConnectivityManager Network if available.
     * 2. Fall back to local P2P interface source address binding.
     * 3. If neither available, fail explicitly with WIFI_DIRECT_NETWORK_UNAVAILABLE.
     */
    internal fun bindSocketToWifiDirect(socket: Socket, interfaceName: String?) {
        customSocketBinder?.let {
            it(socket, interfaceName)
            return
        }

        // 1. Try ConnectivityManager Network binding
        val cm = try {
            context?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        } catch (t: Throwable) { null }

        if (cm != null) {
            try {
                val dynamicSubnetPrefix = lastWifiP2pInfo?.groupOwnerAddress?.hostAddress?.let { ip ->
                    val lastDot = ip.lastIndexOf('.')
                    if (lastDot > 0) ip.substring(0, lastDot + 1) else null
                }

                val networks = cm.allNetworks
                for (network in networks) {
                    val lp = cm.getLinkProperties(network)
                    val caps = cm.getNetworkCapabilities(network)
                    val attrs = NetworkAttributes(
                        interfaceName = lp?.interfaceName,
                        hasCellular = caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true,
                        hasBluetooth = caps?.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) == true,
                        hasEthernet = caps?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true,
                        hasWifiP2pCapability = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && caps != null) {
                            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_WIFI_P2P)
                        } else false
                    )

                    if (isNetworkCandidateForWifiDirect(interfaceName, attrs, dynamicSubnetPrefix)) {
                        try {
                            network.bindSocket(socket)
                            log.info("Successfully bound unconnected socket to Wi-Fi Direct Network {} (iface={})",
                                network, lp?.interfaceName)
                            return
                        } catch (e: Exception) {
                            log.warn("Failed to bind socket to candidate network {}: {}", network, e.message)
                        }
                    }
                }
            } catch (e: Exception) {
                log.warn("Error querying ConnectivityManager networks: {}", e.message)
            }
        }

        // 2. Interface-bound local source address fallback
        try {
            val dynamicSubnetPrefix = lastWifiP2pInfo?.groupOwnerAddress?.hostAddress?.let { ip ->
                val lastDot = ip.lastIndexOf('.')
                if (lastDot > 0) ip.substring(0, lastDot + 1) else null
            }

            val interfaces = NetworkInterface.getNetworkInterfaces()
            if (interfaces != null) {
                while (interfaces.hasMoreElements()) {
                    val iface = interfaces.nextElement()
                    val matchesExplicit = interfaceName != null && iface.name == interfaceName
                    val isP2pInterface = iface.name.startsWith("p2p") || iface.name.contains("p2p")

                    // Strictly verify interface belongs to P2P group: do NOT accept wlan0, rmnet, or loopback!
                    if (!matchesExplicit && !isP2pInterface) {
                        continue
                    }

                    val addrsList = ArrayList<Inet4Address>()
                    val addrs = iface.inetAddresses
                    while (addrs.hasMoreElements()) {
                        val addr = addrs.nextElement()
                        if (addr is Inet4Address && !addr.isLoopbackAddress) {
                            val host = addr.hostAddress
                            if (host != null && (host.startsWith("192.168.49.") ||
                                (dynamicSubnetPrefix != null && host.startsWith(dynamicSubnetPrefix)))) {
                                addrsList.add(addr)
                            }
                        }
                    }

                    if (addrsList.isNotEmpty()) {
                        for (addr in addrsList) {
                            socket.bind(InetSocketAddress(addr, 0))
                            log.info("Bound unconnected socket to local Wi-Fi Direct interface {} source address {}",
                                iface.name, addr.hostAddress)
                            return
                        }
                    }
                }
            }
        } catch (e: Exception) {
            log.warn("Interface-bound fallback check failed: {}", e.message)
        }

        // 3. Neither Android Network nor local P2P interface address could be found
        val dynamicSubnet = lastWifiP2pInfo?.groupOwnerAddress?.hostAddress?.let { ip ->
            val lastDot = ip.lastIndexOf('.')
            if (lastDot > 0) ip.substring(0, lastDot + 1) else null
        }
        throw IOException("WIFI_DIRECT_NETWORK_UNAVAILABLE: No verified Wi-Fi Direct network or interface belongs to current group [interface=$interfaceName, dynamicSubnet=$dynamicSubnet]")
    }

    data class NetworkAttributes(
        val interfaceName: String?,
        val hasCellular: Boolean = false,
        val hasBluetooth: Boolean = false,
        val hasEthernet: Boolean = false,
        val hasWifiP2pCapability: Boolean = false
    )

    /**
     * Determines whether an Android Network belongs to the active Wi-Fi Direct P2P group.
     * Enforces Rule 2:
     * - Never identifies cellular, bluetooth, or ethernet networks as Wi-Fi Direct.
     * - Prioritizes authoritative P2P capability and exact group interface name match.
     * - Rejects standard non-P2P interfaces (e.g., wlan0 station mode) even if their private IP matches.
     */
    internal fun isNetworkCandidateForWifiDirect(
        expectedInterfaceName: String?,
        attrs: NetworkAttributes,
        dynamicSubnetPrefix: String?
    ): Boolean {
        // 1. Strictly exclude non-Wi-Fi transports (cellular, bluetooth, ethernet)
        if (attrs.hasCellular || attrs.hasBluetooth || attrs.hasEthernet) {
            return false
        }

        val ifaceName = attrs.interfaceName

        // 2. Authoritative exact interface match from WifiP2pGroup
        if (expectedInterfaceName != null && ifaceName == expectedInterfaceName) {
            return true
        }

        // 3. Explicit Android platform NET_CAPABILITY_WIFI_P2P capability (API 29+)
        if (attrs.hasWifiP2pCapability) {
            return true
        }

        // 4. Recognized P2P virtual interface naming (e.g., p2p-wlan0-0, p2p0, wigig-p2p)
        val isP2pInterfaceName = ifaceName != null && (
            ifaceName.startsWith("p2p") || ifaceName.contains("p2p") || ifaceName.startsWith("wigig-p2p")
        )
        if (isP2pInterfaceName) {
            return true
        }

        // 5. Rule 2 enforcement: NEVER match a standard non-P2P interface (e.g. wlan0 station mode,
        // rmnet0, or null) solely because an IP address matches 192.168.49.x or dynamicSubnetPrefix!
        return false
    }

    override fun stopDiscovery() {
        super.stopDiscovery()
        peerBroadcastReceiver?.let {
            try {
                context?.unregisterReceiver(it)
            } catch (ignored: Exception) {}
            peerBroadcastReceiver = null
        }
        if (p2pManager != null && channel != null) {
            try {
                p2pManager.stopPeerDiscovery(channel, null)
            } catch (ignored: Exception) {}
        }
        handleDisconnected()
        discoveredDevices.clear()
    }
}
