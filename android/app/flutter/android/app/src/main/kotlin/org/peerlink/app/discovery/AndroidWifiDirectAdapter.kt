package org.peerlink.app.discovery

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pDeviceList
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import org.peerlink.core.android.discovery.WifiDirectDiscoveryAdapter
import org.peerlink.core.android.discovery.DiscoveryAdapter.DiscoveryCallback
import org.peerlink.protocol.v1.PeerId

/**
 * Android platform WifiP2pManager implementation bridging to WifiDirectDiscoveryAdapter.
 * Handles permission validation, peer broadcast reception, and route extraction.
 */
class AndroidWifiDirectAdapter(private val context: Context) : WifiDirectDiscoveryAdapter(
    context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_WIFI_DIRECT)
) {
    private val p2pManager: WifiP2pManager? = context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    private val channel: WifiP2pManager.Channel? = p2pManager?.initialize(context, context.mainLooper, null)

    private var peerBroadcastReceiver: BroadcastReceiver? = null
    private var lastCallback: DiscoveryCallback? = null

    /**
     * Optional permission checker hook for testing permission grant/denial/revocation.
     */
    var permissionChecker: ((Context) -> Boolean)? = null

    fun hasNearbyWifiPermission(): Boolean {
        permissionChecker?.let { return it(context) }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(android.Manifest.permission.NEARBY_WIFI_DEVICES) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
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
                    override fun onSuccess() {}
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
        if (peerBroadcastReceiver == null && p2pManager != null && channel != null) {
            val filter = IntentFilter().apply {
                addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
            }
            peerBroadcastReceiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context?, intent: Intent?) {
                    when (intent?.action) {
                        WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                            try {
                                p2pManager.requestPeers(channel) { deviceList: WifiP2pDeviceList? ->
                                    handlePeersChanged(deviceList)
                                }
                            } catch (ignored: SecurityException) {}
                        }
                    }
                }
            }
            try {
                context.registerReceiver(peerBroadcastReceiver, filter)
            } catch (ignored: Exception) {}
        }
    }

    internal fun handlePeersChanged(deviceList: WifiP2pDeviceList?) {
        if (deviceList == null || !isDiscovering) return
        for (device in deviceList.deviceList) {
            val address = device.deviceAddress ?: continue
            val peerIdStr = "p2p_" + address.replace(":", "").lowercase()
            val peerId = PeerId.newBuilder().setValue(peerIdStr).build()
            val name = if (!device.deviceName.isNullOrBlank()) device.deviceName else "Wi-Fi Direct Peer"
            // Standard Wi-Fi Direct legacy GO IP fallback
            val host = "192.168.49.1"
            notifyPeerDiscovered(peerId, name, host, 8765, listOf("TCP_TLS", "QUIC"))
        }
    }

    override fun stopDiscovery() {
        super.stopDiscovery()
        peerBroadcastReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (ignored: Exception) {}
            peerBroadcastReceiver = null
        }
        if (p2pManager != null && channel != null) {
            try {
                p2pManager.stopPeerDiscovery(channel, null)
            } catch (ignored: Exception) {}
        }
    }
}
