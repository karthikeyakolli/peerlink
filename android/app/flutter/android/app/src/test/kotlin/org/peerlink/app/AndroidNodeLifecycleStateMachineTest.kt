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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Phase 1 Acceptance Gate: Core Lifecycle, Operation Contracts & Observability.
 * Tests:
 * 1. Valid state transitions: STOPPED -> STARTING -> CHECKING_CAPABILITIES -> DISCOVERING -> READY -> CONNECTED -> TRANSFERRING -> READY -> STOPPING -> STOPPED.
 * 2. Repeated-start safety: Calling start() repeatedly is strictly idempotent.
 * 3. Concurrent-start protection: Multithreaded start() calls execute safely without race conditions.
 * 4. Distinct states: Separation of READY vs CONNECTED vs TRANSFERRING.
 * 5. Typed capability inspection: Truthful reporting of interfaces, listeners, and permissions.
 * 6. Error & degradation propagation.
 */
class AndroidNodeLifecycleStateMachineTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var facade: AndroidNodeFacade
    private lateinit var keystoreManager: AndroidKeystoreManager
    private lateinit var stateMachine: AndroidNodeStateMachine

    @Before
    fun setUp() {
        val rootDir = tempFolder.newFolder("node_root")
        val masterKeyProvider = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val keyStore = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "test_master")
        val metaStore = FileIdentityMetadataStore(rootDir)

        keystoreManager = AndroidKeystoreManager.createOrLoad(
            keyStore,
            metaStore,
            "Pixel 9 Pro",
            "Android 15",
            "0.1.0",
            false,
            "SOFTWARE_TEST_HARNESS"
        )

        val initialContext = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .storagePermissionGranted(true)
            .build()
        stateMachine = AndroidNodeStateMachine(initialContext)

        val storageBridge = object : AndroidStorageAbstraction.ContentResolverBridge {
            override fun openInputStream(uri: String?) = ByteArray(0).inputStream()
            override fun openOutputStream(uri: String?) = ByteArrayOutputStream()
            override fun delete(uri: String?) = true
            override fun exists(uri: String?) = true
            override fun getLength(uri: String?) = 1024L
            override fun getDisplayName(uri: String?) = "test.pdf"
            override fun getLastModified(uri: String?) = 1000L
            override fun isDirectory(uri: String?) = false
            override fun listChildren(treeUri: String?) = emptyList<String>()
            override fun checkReadPermission(uri: String?) = true
            override fun checkWritePermission(uri: String?) = true
        }
        val storageAbstraction = AndroidStorageAbstraction(storageBridge)

        val clipboardBridge = object : AndroidClipboardAdapter.SystemClipboardBridge {
            override fun readText(): String = "test clipboard"
            override fun writeText(text: String?, isSensitive: Boolean) {}
            override fun hasText(): Boolean = true
        }
        val clipboardAdapter = AndroidClipboardAdapter(
            keystoreManager.peerId.value,
            ClipboardSyncMode.TEXT,
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
    fun testValidLifecycleStateTransitionsFromStoppedToReady() {
        assertEquals("Initial node lifecycle must be STOPPED", NodeLifecycleState.STOPPED, facade.lifecycleState)
        assertFalse("Stopped node must not be operational", facade.lifecycleState.isOperational)

        val recordedTransitions = mutableListOf<NodeLifecycleState>()
        facade.addLifecycleListener { _, newState, _ ->
            recordedTransitions.add(newState)
        }

        facade.start()

        assertEquals("Node must reach READY state after start()", NodeLifecycleState.READY, facade.lifecycleState)
        assertTrue("Node in READY state must be operational", facade.lifecycleState.isOperational)
        assertTrue("Node in READY state must accept transfers", facade.lifecycleState.canAcceptTransfers())
        assertFalse("Node in READY state is not yet transferring", facade.lifecycleState.isTransferring)

        assertTrue("STARTING state must be visited", recordedTransitions.contains(NodeLifecycleState.STARTING))
        assertTrue("CHECKING_CAPABILITIES state must be visited", recordedTransitions.contains(NodeLifecycleState.CHECKING_CAPABILITIES))
        assertTrue("DISCOVERING state must be visited", recordedTransitions.contains(NodeLifecycleState.DISCOVERING))
        assertTrue("READY state must be the final operational transition", recordedTransitions.contains(NodeLifecycleState.READY))
    }

    @Test
    fun testRepeatedStartSafetyIsIdempotent() {
        facade.start()
        assertEquals(NodeLifecycleState.READY, facade.lifecycleState)

        val transitionCount = AtomicInteger(0)
        facade.addLifecycleListener { _, _, _ ->
            transitionCount.incrementAndGet()
        }

        // Call start() repeatedly
        facade.start()
        facade.start()
        facade.start()

        assertEquals("Node state must remain READY without modification", NodeLifecycleState.READY, facade.lifecycleState)
        assertEquals("Duplicate start() must NOT trigger state transition listeners", 0, transitionCount.get())
    }

    @Test
    fun testConcurrentStartProtection() {
        val threads = 8
        val executor = Executors.newFixedThreadPool(threads)
        val latch = CountDownLatch(threads)

        for (i in 0 until threads) {
            executor.submit {
                try {
                    facade.start()
                } finally {
                    latch.countDown()
                }
            }
        }

        assertTrue("All concurrent start threads must complete within timeout", latch.await(5, TimeUnit.SECONDS))
        executor.shutdown()

        assertEquals("Node must safely converge to READY state under concurrency", NodeLifecycleState.READY, facade.lifecycleState)
    }

    @Test
    fun testReadinessVsConnectedVsTransferringSeparation() {
        facade.start()
        assertEquals(NodeLifecycleState.READY, facade.lifecycleState)

        // 1. Establish authenticated connection with a peer
        facade.setLifecycleState(NodeLifecycleState.CONNECTED, "Ed25519 handshake verified with peer-abc-123")
        assertEquals(NodeLifecycleState.CONNECTED, facade.lifecycleState)
        assertTrue(facade.lifecycleState.canAcceptTransfers())
        assertFalse(facade.lifecycleState.isTransferring)

        // 2. Active payload streaming begins
        facade.setLifecycleState(NodeLifecycleState.TRANSFERRING, "Streaming chunk batch tx_777")
        assertEquals(NodeLifecycleState.TRANSFERRING, facade.lifecycleState)
        assertTrue(facade.lifecycleState.isTransferring)

        // 3. Payload streaming completes; node returns to READY
        facade.notifyTransferFinished("tx_777", "presentation.pdf", true, null)
        assertEquals("Node must return to READY when all active transfers finish", NodeLifecycleState.READY, facade.lifecycleState)

        // 4. Clean shutdown transitions through STOPPING to STOPPED
        facade.stop()
        assertEquals(NodeLifecycleState.STOPPED, facade.lifecycleState)
    }

    @Test
    fun testTypedNodeCapabilitiesInspection() {
        facade.start()
        val caps = facade.nodeCapabilities

        assertNotNull(caps.availableNetworkInterfaces)
        assertNotNull(caps.activeListeners)
        assertTrue("Active listeners must include TCP TLS socket", caps.activeListeners.any { it.contains("8765") })
        assertTrue("Usable transports must contain TCP_TLS", caps.usableTransports.contains("TCP_TLS"))
        assertTrue("Missing permissions should be empty when storage granted", caps.missingPermissions.isEmpty())
        assertNotNull(caps.securityLevel)
        assertTrue("canTransfer must be true for ready node", caps.canTransfer())

        val map = caps.toMap()
        assertEquals(caps.securityLevel, map["securityLevel"])
        assertEquals(true, map["canTransfer"])
    }

    @Test
    fun testUnavailablePrerequisiteTransition() {
        // Create context where critical storage permission is denied
        val deniedContext = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .storagePermissionGranted(false)
            .build()
        stateMachine.updateContext(deniedContext)

        facade.start()

        assertEquals("Node must transition to UNAVAILABLE when critical prerequisites fail", NodeLifecycleState.UNAVAILABLE, facade.lifecycleState)
        assertFalse(facade.lifecycleState.isOperational)
    }
}
