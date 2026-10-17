package org.peerlink.app.discovery

import android.content.Context
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pManager
import org.peerlink.core.android.discovery.WifiDirectDiscoveryAdapter
import org.peerlink.core.android.discovery.DiscoveryAdapter.DiscoveryCallback
import org.peerlink.protocol.v1.PeerId

/**
 * Android platform WifiP2pManager implementation bridging to WifiDirectDiscoveryAdapter.
 */
class AndroidWifiDirectAdapter(context: Context) : WifiDirectDiscoveryAdapter(
    context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_WIFI_DIRECT)
) {
    private val p2pManager: WifiP2pManager? = context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    private val channel: WifiP2pManager.Channel? = p2pManager?.initialize(context, context.mainLooper, null)

    override fun startDiscovery(callback: DiscoveryCallback) {
        super.startDiscovery(callback)
        if (p2pManager != null && channel != null) {
            try {
                p2pManager.discoverPeers(channel, object : WifiP2pManager.ActionListener {
                    override fun onSuccess() {}
                    override fun onFailure(reasonCode: Int) {
                        callback.onDiscoveryError(technologyName, "Wi-Fi Direct peer discovery failed code $reasonCode")
                    }
                })
            } catch (ignored: SecurityException) {}
        }
    }

    override fun stopDiscovery() {
        super.stopDiscovery()
        if (p2pManager != null && channel != null) {
            try {
                p2pManager.stopPeerDiscovery(channel, null)
            } catch (ignored: Exception) {}
        }
    }
}
