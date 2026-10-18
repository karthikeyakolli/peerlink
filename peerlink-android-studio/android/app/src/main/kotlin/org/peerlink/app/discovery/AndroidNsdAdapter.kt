package org.peerlink.app.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import org.peerlink.core.android.discovery.NsdDiscoveryAdapter
import org.peerlink.core.android.discovery.DiscoveryAdapter.DiscoveryCallback
import org.peerlink.protocol.v1.PeerId
import java.net.InetAddress

/**
 * Android platform NsdManager implementation bridging to NsdDiscoveryAdapter.
 */
class AndroidNsdAdapter(private val context: Context) : NsdDiscoveryAdapter(true) {

    private val nsdManager: NsdManager? = context.getSystemService(Context.NSD_SERVICE) as? NsdManager
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var lastCallback: DiscoveryCallback? = null

    /**
     * Optional permission checker hook for testing permission grant/denial/revocation.
     */
    var permissionChecker: ((Context) -> Boolean)? = null

    /**
     * Verifies whether the runtime has local network access permissions.
     * Android 17 (API 37+) introduces android.permission.ACCESS_LOCAL_NETWORK for configurations
     * targeting API 37 or higher. Configurations targeting API < 37 remain backward-compatible under INTERNET.
     */
    fun hasLocalNetworkPermission(): Boolean {
        permissionChecker?.let { return it(context) }
        if (android.os.Build.VERSION.SDK_INT >= 37 && context.applicationInfo.targetSdkVersion >= 37) {
            val localNet = context.checkSelfPermission("android.permission.ACCESS_LOCAL_NETWORK")
            if (localNet != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                return false
            }
        }
        return true
    }

    override fun startAdvertising(localPeerId: PeerId, displayName: String, port: Int) {
        if (!hasLocalNetworkPermission()) {
            return
        }
        super.startAdvertising(localPeerId, displayName, port)
        if (nsdManager == null) return

        val serviceInfo = NsdServiceInfo().apply {
            serviceName = "PeerLink-${localPeerId.value.take(8)}"
            serviceType = SERVICE_TYPE
            setPort(port)
            setAttribute("peerId", localPeerId.value)
            setAttribute("name", displayName)
        }

        registrationListener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(NsdServiceInfo: NsdServiceInfo) {}
            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}
            override fun onServiceUnregistered(arg0: NsdServiceInfo) {}
            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}
        }

        try {
            nsdManager.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)
        } catch (ignored: Exception) {}
    }

    override fun stopAdvertising() {
        super.stopAdvertising()
        registrationListener?.let {
            try {
                nsdManager?.unregisterService(it)
            } catch (ignored: Exception) {}
            registrationListener = null
        }
    }

    override fun startDiscovery(callback: DiscoveryCallback) {
        lastCallback = callback
        if (!hasLocalNetworkPermission()) {
            callback.onDiscoveryError(technologyName, "PERMISSION_DENIED: Local network access permission is required")
            return
        }
        super.startDiscovery(callback)
        if (nsdManager == null) return

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) {}

            override fun onServiceFound(service: NsdServiceInfo) {
                if (service.serviceType.contains("peerlink")) {
                    nsdManager.resolveService(service, object : NsdManager.ResolveListener {
                        override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}

                        override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                            val host: InetAddress = serviceInfo.host
                            val port: Int = serviceInfo.port
                            val peerIdAttr = serviceInfo.attributes["peerId"]?.let { String(it) }
                                ?: serviceInfo.serviceName
                            val nameAttr = serviceInfo.attributes["name"]?.let { String(it) }
                                ?: serviceInfo.serviceName

                            notifyPeerDiscovered(
                                PeerId.newBuilder().setValue(peerIdAttr).build(),
                                nameAttr,
                                host.hostAddress ?: "127.0.0.1",
                                port,
                                listOf("QUIC", "TCP_TLS")
                            )
                        }
                    })
                }
            }

            override fun onServiceLost(service: NsdServiceInfo) {
                val peerIdStr = service.attributes?.get("peerId")?.let { String(it) }
                    ?: service.serviceName
                notifyPeerLost(PeerId.newBuilder().setValue(peerIdStr).build())
            }

            override fun onDiscoveryStopped(serviceType: String) {}
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                if (discoveryListener === this) {
                    callback.onDiscoveryError(technologyName, "NSD discovery failed with code $errorCode")
                }
            }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
        }

        try {
            nsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (e: Exception) {
            callback.onDiscoveryError(technologyName, e.message ?: "Failed to start NSD discovery")
        }
    }

    override fun stopDiscovery() {
        super.stopDiscovery()
        discoveryListener?.let {
            try {
                nsdManager?.stopServiceDiscovery(it)
            } catch (ignored: Exception) {}
            discoveryListener = null
        }
    }

    fun restartDiscovery() {
        stopDiscovery()
        try {
            Thread.sleep(100)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        lastCallback?.let { startDiscovery(it) }
    }
}
