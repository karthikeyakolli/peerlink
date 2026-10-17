package org.peerlink.app.discovery

import android.content.Context
import android.net.wifi.aware.WifiAwareManager
import org.peerlink.core.android.discovery.WifiAwareDiscoveryAdapter

/**
 * Android platform WifiAwareManager implementation bridging to WifiAwareDiscoveryAdapter.
 */
class AndroidWifiAwareAdapter(context: Context) : WifiAwareDiscoveryAdapter(
    context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_WIFI_AWARE)
) {
    private val awareManager: WifiAwareManager? =
        context.getSystemService(Context.WIFI_AWARE_SERVICE) as? WifiAwareManager

    override fun isAvailable(): Boolean {
        return super.isAvailable() && (awareManager?.isAvailable ?: false)
    }
}
