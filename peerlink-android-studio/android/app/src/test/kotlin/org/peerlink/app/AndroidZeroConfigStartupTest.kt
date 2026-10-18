package org.peerlink.app

import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.peerlink.core.android.*
import org.peerlink.core.android.discovery.AndroidDiscoveryEngine
import org.peerlink.core.collaboration.clipboard.ClipboardSyncMode
import org.peerlink.protocol.v1.PeerId
import java.io.ByteArrayOutputStream

/**
 * Phase 2 Acceptance Gate: Zero-Configuration Startup & Permission Automation.
 *
 * Verifies:
 * 1. Automatic zero-configuration node initialization to READY.
 * 2. Truthful capability reconciliation (listeners, interfaces, Keystore tier).
 * 3. Graceful handling of denied runtime permissions (Notifications, Nearby Devices, Camera, Local Network).
 * 4. Bounded exponential backoff retry on transient unavailable state.
 * 5. Cancellation of pending retries on node stop.
 * 6. Automatic startup resumption when environmental prerequisites recover.
 */
class AndroidZeroConfigStartupTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var facade: AndroidNodeFacade
    private lateinit var keystoreManager: AndroidKeystoreManager
    private lateinit var stateMachine: AndroidNodeStateMachine

    @Before
    fun setUp() {
        val rootDir = tempFolder.newFolder("node_zero_config_test")
        val masterKeyProvider = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val keyStore = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "test_master")
        val metaStore = FileIdentityMetadataStore(rootDir)

        keystoreManager = AndroidKeystoreManager.createOrLoad(
            keyStore,
            metaStore,
            "Pixel 9 Pro Test",
            "Android 15",
            "1.0.0",
            true,
            "STRONGBOX"
        )

        val initialContext = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .batteryLevelPercent(90)
            .batteryCharging(true)
            .storagePermissionGranted(true)
            .notificationPermissionGranted(true)
            .nearbyDevicesPermissionGranted(true)
            .localNetworkPermissionGranted(true)
            .cameraPermissionGranted(true)
            .build()
        stateMachine = AndroidNodeStateMachine(initialContext)

        val storageBridge = object : AndroidStorageAbstraction.ContentResolverBridge {
            override fun openInputStream(uri: String?) = ByteArray(0).inputStream()
            override fun openOutputStream(uri: String?) = ByteArrayOutputStream()
            override fun delete(uri: String?) = true
            override fun exists(uri: String?) = true
            override fun getLength(uri: String?) = 1024L
            override fun getDisplayName(uri: String?) = "test.txt"
            override fun getLastModified(uri: String?) = 1000L
            override fun isDirectory(uri: String?) = false
            override fun listChildren(treeUri: String?) = emptyList<String>()
            override fun checkReadPermission(uri: String?) = true
            override fun checkWritePermission(uri: String?) = true
        }
        val storageAbstraction = AndroidStorageAbstraction(storageBridge)

        val clipboardBridge = object : AndroidClipboardAdapter.SystemClipboardBridge {
            private var clip = ""
            override fun readText(): String = clip
            override fun writeText(text: String?, isSensitive: Boolean) { clip = text ?: "" }
            override fun hasText(): Boolean = clip.isNotEmpty()
        }
        val clipboardAdapter = AndroidClipboardAdapter(
            keystoreManager.peerId.value,
            ClipboardSyncMode.TEXT_AND_URL,
            clipboardBridge,
            stateMachine
        )

        val notifBridge = object : AndroidNotificationController.PlatformNotificationBridge {
            override fun showTransferProgress(transferId: String?, title: String?, progressPercent: Int, bytesTransferred: Long, totalBytes: Long) {}
            override fun dismissTransferProgress(transferId: String?) {}
            override fun showPairingPrompt(sessionId: String?, peerId: PeerId?, peerName: String?, sasPin: String?) {}
            override fun dismissPairingPrompt(sessionId: String?) {}
            override fun showStatusNotification(title: String?, message: String?) {}
        }
        val notificationController = AndroidNotificationController(notifBridge)

        val discoveryEngine = AndroidDiscoveryEngine(emptyList())

        facade = AndroidNodeFacade(
            stateMachine,
            keystoreManager,
            storageAbstraction,
            clipboardAdapter,
            discoveryEngine,
            notificationController
        )
    }

    @Test
    fun testZeroConfigStartupInitializesToReady() {
        assertEquals(NodeLifecycleState.STOPPED, facade.lifecycleState)

        // Zero-config startup: single authoritative start() call
        facade.start()

        assertEquals(NodeLifecycleState.READY, facade.lifecycleState)
        val caps = facade.nodeCapabilities
        assertTrue(caps.canTransfer())
        assertTrue(caps.activeListeners.any { it.contains("8765") })
        assertEquals("STRONGBOX", caps.securityLevel)
        assertTrue(caps.missingPermissions.isEmpty())
    }

    @Test
    fun testPermissionDenialReportsMissingPermissionsGracefully() {
        // Environmental context with multiple missing permissions
        val restrictedContext = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .storagePermissionGranted(true)
            .notificationPermissionGranted(false)
            .nearbyDevicesPermissionGranted(false)
            .localNetworkPermissionGranted(false)
            .cameraPermissionGranted(false)
            .build()
        facade.updateContext(restrictedContext)
        facade.start()

        // Node can still run (degraded/ready for direct routes) but truthfully reports missing permissions
        val caps = facade.nodeCapabilities
        val missing = caps.missingPermissions
        assertTrue(missing.contains("Notifications"))
        assertTrue(missing.contains("Nearby Devices"))
        assertTrue(missing.contains("Local Network"))
        assertTrue(missing.contains("Camera"))
        assertFalse(missing.contains("Storage (SAF/Media)"))
    }

    @Test
    fun testTransientPrerequisiteFailureTriggersBoundedRetry() {
        // Start while offline
        val offlineContext = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.OFFLINE)
            .build()
        facade.updateContext(offlineContext)

        facade.start()

        // Should transition to UNAVAILABLE and trigger first retry attempt
        assertEquals(NodeLifecycleState.UNAVAILABLE, facade.lifecycleState)
        assertEquals(1, facade.retryCount)

        val caps = facade.nodeCapabilities
        assertFalse(caps.canTransfer())
    }

    @Test
    fun testStopCancelsRetriesAndCleansUp() {
        val offlineContext = AndroidNodeContext.builder()
            .networkType(AndroidNodeContext.NetworkType.OFFLINE)
            .build()
        facade.updateContext(offlineContext)
        facade.start()

        assertEquals(NodeLifecycleState.UNAVAILABLE, facade.lifecycleState)
        assertEquals(1, facade.retryCount)

        // Stop should cleanly reset retries and transition to STOPPED
        facade.stop()
        assertEquals(NodeLifecycleState.STOPPED, facade.lifecycleState)
        assertEquals(0, facade.retryCount)
    }

    @Test
    fun testEnvironmentalRestorationResumesNodeStartup() {
        val offlineContext = AndroidNodeContext.builder()
            .networkType(AndroidNodeContext.NetworkType.OFFLINE)
            .build()
        facade.updateContext(offlineContext)
        facade.start()
        assertEquals(NodeLifecycleState.UNAVAILABLE, facade.lifecycleState)

        // Network recovers to Wi-Fi
        val onlineContext = AndroidNodeContext.builder()
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .build()
        facade.updateContext(onlineContext)

        // Facade automatically resumes and transitions to READY without manual intervention
        assertEquals(NodeLifecycleState.READY, facade.lifecycleState)
        assertTrue(facade.nodeCapabilities.canTransfer())
    }

    @Test
    fun testRepeatedStartCallsAreIdempotent() {
        facade.start()
        assertEquals(NodeLifecycleState.READY, facade.lifecycleState)

        // Repeated start calls while operational should be safe no-ops
        facade.start()
        facade.start()
        assertEquals(NodeLifecycleState.READY, facade.lifecycleState)
    }
}
