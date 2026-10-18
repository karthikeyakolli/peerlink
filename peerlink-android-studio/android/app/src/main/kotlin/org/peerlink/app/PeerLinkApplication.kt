package org.peerlink.app

import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import java.io.File
import org.peerlink.app.discovery.AndroidNsdAdapter
import org.peerlink.app.discovery.AndroidWifiAwareAdapter
import org.peerlink.app.discovery.AndroidWifiDirectAdapter
import org.peerlink.app.keystore.AndroidKeyStoreProvider
import org.peerlink.app.notification.AndroidNotificationBridge
import org.peerlink.app.storage.SafStorageProvider
import org.peerlink.app.worker.PeerLinkSyncWorker
import org.peerlink.core.android.*
import org.peerlink.core.android.discovery.AndroidDiscoveryEngine
import org.peerlink.core.android.discovery.TransportRouteSelector
import org.peerlink.core.collaboration.clipboard.ClipboardSyncMode
import org.peerlink.core.security.InMemoryTrustStore
import org.peerlink.core.transfer.PeerTransferEngine
import org.peerlink.core.transport.PeerSessionManager
import org.peerlink.core.transport.StandardTcpTransportProvider
import org.peerlink.core.transport.TransportCapabilityNegotiator
import org.peerlink.protocol.v1.ProtocolVersion

/**
 * Android Application entry point initializing the authoritative Android Node Facade.
 */
class PeerLinkApplication : Application() {

    var nodeFacade: AndroidNodeFacade? = null
        private set

    var recoveryManager: AndroidStartupRecoveryManager? = null
        private set

    override fun onCreate() {
        super.onCreate()
        initializeNode()
        PeerLinkSyncWorker.schedulePeriodicSync(this)
    }

    private fun initializeNode() {
        // 1. Environmental context
        val initialContext = buildCurrentContext(inForeground = false)
        val stateMachine = AndroidNodeStateMachine(initialContext)

        // 2. Ed25519 Identity protected at rest by AndroidKeyStore AES-256
        val masterKeyProvider = AndroidKeyStoreProvider()
        val secureKeyStore = AndroidKeyStoreSecureKeyStore(filesDir, masterKeyProvider, "peerlink_master_key")
        val metadataStore = FileIdentityMetadataStore(filesDir)
        val isHw = masterKeyProvider.isMasterKeyHardwareBacked("peerlink_master_key")
        val secLevel = masterKeyProvider.getSecurityLevel("peerlink_master_key")
        val keystoreManager = AndroidKeystoreManager.createOrLoad(
            secureKeyStore,
            metadataStore,
            "Android Device",
            "Android " + Build.VERSION.RELEASE,
            "0.1.0",
            isHw,
            "Software Ed25519 (Protected at rest by Keystore $secLevel)"
        )

        // 3. Storage Abstraction (SAF)
        val storageProvider = SafStorageProvider(this)
        val storageAbstraction = AndroidStorageAbstraction(storageProvider)

        // 4. Clipboard
        val clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
        val clipboardBridge = object : AndroidClipboardAdapter.SystemClipboardBridge {
            override fun readText(): String {
                val clip = clipboardManager.primaryClip
                return if (clip != null && clip.itemCount > 0) {
                    clip.getItemAt(0).text?.toString() ?: ""
                } else ""
            }

            override fun writeText(text: String, isSensitive: Boolean) {
                val clip = android.content.ClipData.newPlainText("PeerLink", text)
                if (isSensitive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    clip.description.extras = android.os.PersistableBundle().apply {
                        putBoolean(android.content.ClipDescription.EXTRA_IS_SENSITIVE, true)
                    }
                }
                clipboardManager.setPrimaryClip(clip)
            }

            override fun hasText(): Boolean = clipboardManager.hasPrimaryClip()
        }
        val clipboardAdapter = AndroidClipboardAdapter(
            keystoreManager.peerId.value,
            ClipboardSyncMode.TEXT_AND_URL,
            clipboardBridge,
            stateMachine
        )

        // 5. Discovery Adapters
        val nsdAdapter = AndroidNsdAdapter(this)
        val wifiDirectAdapter = AndroidWifiDirectAdapter(this)
        val wifiAwareAdapter = AndroidWifiAwareAdapter(this)
        val discoveryEngine = AndroidDiscoveryEngine(listOf(nsdAdapter, wifiDirectAdapter, wifiAwareAdapter))

        // 6. Notification Controller
        val notificationBridge = AndroidNotificationBridge(this)
        val notificationController = AndroidNotificationController(notificationBridge)

        // 7. Authoritative Persistent SQLite Operation Journal & Startup Recovery (Rule 9)
        val operationJournal = AndroidSqliteOperationJournal(this)
        val recoveryManager = AndroidStartupRecoveryManager(operationJournal)
        this.recoveryManager = recoveryManager

        val stagingRoot = File(filesDir, "staging").apply { mkdirs() }.toPath()
        val destRoot = File(filesDir, "received").apply { mkdirs() }.toPath()
        recoveryManager.reconcileOnStartup(stagingRoot, destRoot)

        val transferEngine = PeerTransferEngine(operationJournal, stagingRoot)

        // 8. Transport, Session Manager, and Route Selection
        val transportProvider = StandardTcpTransportProvider("0.0.0.0")
        val trustStore = InMemoryTrustStore()
        val protocolVersion = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build()
        val sessionManager = PeerSessionManager(
            keystoreManager.peerIdentity,
            keystoreManager.deviceIdentity,
            keystoreManager.signer,
            trustStore,
            protocolVersion,
            protocolVersion,
            TransportCapabilityNegotiator(listOf(transportProvider))
        )
        val routeSelector = TransportRouteSelector(transportProvider)

        // 9. Assemble master Facade
        val facade = AndroidNodeFacade(
            stateMachine,
            keystoreManager,
            storageAbstraction,
            clipboardAdapter,
            discoveryEngine,
            notificationController,
            operationJournal,
            transferEngine,
            transportProvider,
            sessionManager,
            routeSelector,
            destRoot,
            trustStore
        )
        this.nodeFacade = facade
        facade.start()

        registerSystemBroadcastReceivers()
    }

    private fun registerSystemBroadcastReceivers() {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        connectivityManager.registerNetworkCallback(request, object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                updateEnvironmentalState()
            }

            override fun onLost(network: Network) {
                updateEnvironmentalState()
            }
        })
    }

    fun updateEnvironmentalState(inForeground: Boolean? = null) {
        val facade = nodeFacade ?: return
        val currentFg = inForeground ?: facade.currentContext.isAppInForeground
        val newContext = buildCurrentContext(currentFg)
        facade.updateContext(newContext)
    }

    private fun buildCurrentContext(inForeground: Boolean): AndroidNodeContext {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val isPowerSave = powerManager.isPowerSaveMode
        val isDeviceIdle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            powerManager.isDeviceIdleMode
        } else false

        // Network detection
        val activeNetwork = connectivityManager.activeNetwork
        val caps = connectivityManager.getNetworkCapabilities(activeNetwork)
        val netType = when {
            caps == null -> AndroidNodeContext.NetworkType.OFFLINE
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> AndroidNodeContext.NetworkType.WIFI
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> AndroidNodeContext.NetworkType.ETHERNET
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> {
                if (connectivityManager.isActiveNetworkMetered) {
                    AndroidNodeContext.NetworkType.CELLULAR_METERED
                } else {
                    AndroidNodeContext.NetworkType.CELLULAR_UNMETERED
                }
            }
            else -> AndroidNodeContext.NetworkType.OTHER
        }

        // Battery detection
        val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: 100
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: 100
        val batteryPct = if (scale > 0) (level * 100 / scale) else 100
        val status = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL

        // Real runtime permission checks
        val notifGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else true

        val nearbyGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(android.Manifest.permission.NEARBY_WIFI_DEVICES) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else true

        val localNetGranted = if (Build.VERSION.SDK_INT >= 37 && applicationInfo.targetSdkVersion >= 37) {
            checkSelfPermission("android.permission.ACCESS_LOCAL_NETWORK") == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else true

        val cameraGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(android.Manifest.permission.CAMERA) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else true

        return AndroidNodeContext.builder()
            .appInForeground(inForeground)
            .powerSaveMode(isPowerSave)
            .deviceIdleMode(isDeviceIdle)
            .networkType(netType)
            .batteryCharging(isCharging)
            .batteryLevelPercent(batteryPct)
            .storagePermissionGranted(true) // SAF is default, always granted without broad storage permissions
            .notificationPermissionGranted(notifGranted)
            .nearbyDevicesPermissionGranted(nearbyGranted)
            .localNetworkPermissionGranted(localNetGranted)
            .cameraPermissionGranted(cameraGranted)
            .build()
    }
}
