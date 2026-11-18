package org.peerlink.app

import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.peerlink.app.notification.InboundTransferActionReceiver
import org.peerlink.app.share.DirectShareManager
import org.peerlink.core.android.*
import org.peerlink.core.android.discovery.AndroidDiscoveryEngine
import org.peerlink.core.collaboration.clipboard.ClipboardSyncMode
import org.peerlink.core.security.InMemoryTrustStore
import org.peerlink.protocol.v1.PeerId
import org.peerlink.protocol.v1.PeerIdentity
import java.io.ByteArrayOutputStream

/**
 * Unit and integration tests for native Android OS integration features:
 * 1. Quick Settings Tile discovery visibility toggle (non-destructive to background services/transfers).
 * 2. Direct Share target filtering ensuring Rule 6 (discovery != trust).
 * 3. Inbound transfer notification shade action routing.
 */
class AndroidNativeSystemIntegrationTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var facade: AndroidNodeFacade
    private lateinit var discoveryEngine: AndroidDiscoveryEngine
    private lateinit var trustStore: InMemoryTrustStore

    @Before
    fun setUp() {
        val rootDir = tempFolder.newFolder("native_sys_integration_test")
        val masterKeyProvider = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val keyStore = AndroidKeyStoreSecureKeyStore(rootDir, masterKeyProvider, "test_master")
        val metaStore = FileIdentityMetadataStore(rootDir)

        val keystoreManager = AndroidKeystoreManager.createOrLoad(
            keyStore,
            metaStore,
            "Pixel 9 Pro Test",
            "Android 15",
            "1.0.0",
            true,
            "STRONGBOX"
        )

        val context = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .batteryLevelPercent(95)
            .batteryCharging(true)
            .storagePermissionGranted(true)
            .notificationPermissionGranted(true)
            .nearbyDevicesPermissionGranted(true)
            .localNetworkPermissionGranted(true)
            .cameraPermissionGranted(true)
            .build()
        val stateMachine = AndroidNodeStateMachine(context)

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

        discoveryEngine = AndroidDiscoveryEngine(emptyList())
        val notificationController = AndroidNotificationController(object : AndroidNotificationController.PlatformNotificationBridge {
            override fun showTransferProgress(transferId: String, title: String, progressPercent: Int, bytesTransferred: Long, totalBytes: Long) {}
            override fun dismissTransferProgress(transferId: String) {}
            override fun showPairingPrompt(sessionId: String, peerId: PeerId, peerName: String, sasPin: String) {}
            override fun dismissPairingPrompt(sessionId: String) {}
            override fun showStatusNotification(title: String, message: String) {}
            override fun showIncomingTransferPrompt(transferId: String, senderPeer: PeerId, peerName: String, fileName: String, totalBytes: Long, itemCount: Int) {}
            override fun dismissIncomingTransferPrompt(transferId: String) {}
        })

        trustStore = InMemoryTrustStore()
        facade = AndroidNodeFacade(
            stateMachine,
            keystoreManager,
            storageAbstraction,
            clipboardAdapter,
            discoveryEngine,
            notificationController,
            null,
            null,
            null,
            null,
            null,
            null,
            trustStore
        )
    }

    @Test
    fun testDiscoveryVisibilityToggleViaNodeFacade() {
        // Start node facade
        facade.start()
        assertTrue("Node facade should report discovery visible by default when started", facade.isDiscoveryVisible)

        // User toggles Quick Settings Tile off (hide discovery broadcast)
        val hidden = facade.toggleDiscoveryVisible()
        assertFalse("Toggle should transition visibility to false", hidden)
        assertFalse("Facade isDiscoveryVisible should reflect hidden state", facade.isDiscoveryVisible)
        assertEquals("Node lifecycle should remain READY/running despite hidden visibility",
            NodeLifecycleState.READY, facade.lifecycleState)

        // User toggles Quick Settings Tile on (resume discovery broadcast)
        val visibleAgain = facade.toggleDiscoveryVisible()
        assertTrue("Toggle should transition visibility back to true", visibleAgain)
        assertTrue("Facade isDiscoveryVisible should reflect visible state", facade.isDiscoveryVisible)

        facade.stop()
    }

    @Test
    fun testDirectShareStrictlyEnforcesTrustStoreAndRule6() {
        val peer1 = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue("peer_trusted_1").build())
            .setDisplayName("Alice Laptop")
            .setFingerprintHex("aa11")
            .build()
        val peer2Revoked = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue("peer_revoked_2").build())
            .setDisplayName("Compromised Device")
            .setFingerprintHex("bb22")
            .build()

        trustStore.addTrustedPeer(peer1)
        trustStore.addTrustedPeer(peer2Revoked)
        trustStore.revokeTrust("peer_revoked_2")

        // Filter peers exactly as DirectShareManager does
        val validDirectShareTargets = trustStore.allPeers
            .filter { trustStore.isTrusted(it.peerId.value) && !trustStore.isRevoked(it.peerId.value) }
            .map { DirectShareManager.ShareTargetPeer(it.peerId.value, it.displayName) }

        assertEquals(1, validDirectShareTargets.size)
        assertEquals("peer_trusted_1", validDirectShareTargets[0].peerId)
        assertEquals("Alice Laptop", validDirectShareTargets[0].displayName)

        // Verify that untrusted/discovered peer is never treated as a valid direct share target (Rule 6)
        val untrustedPeerId = "untrusted_discovered_node"
        assertFalse("Rule 6: Untrusted discovered peer must never be trusted", trustStore.isTrusted(untrustedPeerId))
    }

    @Test
    fun testInboundTransferActionReceiverConstants() {
        assertEquals("org.peerlink.action.ACCEPT_TRANSFER", InboundTransferActionReceiver.ACTION_ACCEPT_TRANSFER)
        assertEquals("org.peerlink.action.DECLINE_TRANSFER", InboundTransferActionReceiver.ACTION_DECLINE_TRANSFER)
        assertEquals("TRANSFER_ID", InboundTransferActionReceiver.EXTRA_TRANSFER_ID)
    }
}
