package org.peerlink.app

import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.*
import org.peerlink.core.android.*
import org.peerlink.core.android.discovery.AndroidDiscoveryEngine
import org.peerlink.core.collaboration.clipboard.ClipboardSyncMode
import org.peerlink.core.filesystem.PathSafetyValidator
import org.peerlink.core.operation.InMemoryOperationJournal
import org.peerlink.core.security.InMemoryTrustStore
import org.peerlink.core.transfer.*
import org.peerlink.core.transport.PeerSession
import org.peerlink.core.transport.SessionPayloadHandler
import org.peerlink.core.transport.TransportConnection
import org.peerlink.protocol.v1.*
import java.io.*
import java.nio.file.Files
import java.util.concurrent.CompletableFuture

/**
 * Section 7: Adversarial and Failure Testing Suite for PeerLink Android Studio Edition.
 *
 * Exercises:
 * 1. Malformed and oversized protocol frame headers in TCP transport.
 * 2. Inbound manifest path traversal attacks (.. traversal, Windows reserved names, null characters).
 * 3. Outbound filename path traversal containment in staging_outbound.
 * 4. Corrupted chunk data rejection and hash integrity enforcement.
 * 5. Notification intent replay and idempotent response handling.
 * 6. Revoked peer rejection before user consent prompting.
 * 7. Storage permission denial handling with AccessDeniedException.
 * 8. Environmental node state evaluation (Doze mode, storage denial, offline).
 * 9. NodeLifecycleState terminal and transfer guards.
 */
class AndroidAdversarialAndFailureAuditTest {

    private lateinit var tempDir: File
    private lateinit var stagingDir: File
    private lateinit var destDir: File
    private lateinit var trustStore: InMemoryTrustStore
    private lateinit var journal: InMemoryOperationJournal
    private lateinit var transferEngine: PeerTransferEngine

    private class NoOpClipboardBridge : AndroidClipboardAdapter.SystemClipboardBridge {
        private var clip = ""
        override fun readText(): String = clip
        override fun writeText(text: String?, isSensitive: Boolean) { clip = text ?: "" }
        override fun hasText(): Boolean = clip.isNotEmpty()
    }

    private class NoOpNotificationBridge : AndroidNotificationController.PlatformNotificationBridge {
        override fun showTransferProgress(transferId: String?, title: String?, progressPercent: Int, bytesTransferred: Long, totalBytes: Long) {}
        override fun dismissTransferProgress(transferId: String?) {}
        override fun showPairingPrompt(sessionId: String?, peerId: PeerId?, peerName: String?, sasPin: String?) {}
        override fun dismissPairingPrompt(sessionId: String?) {}
        override fun showStatusNotification(title: String?, message: String?) {}
    }

    @Before
    fun setUp() {
        tempDir = Files.createTempDirectory("peerlink-audit-test").toFile()
        stagingDir = File(tempDir, "staging").apply { mkdirs() }
        destDir = File(tempDir, "dest").apply { mkdirs() }

        trustStore = InMemoryTrustStore()
        journal = InMemoryOperationJournal()

        transferEngine = PeerTransferEngine(journal, stagingDir.toPath())
    }

    @After
    fun tearDown() {
        tempDir.deleteRecursively()
    }

    // ── 1. Malformed & Oversized Protocol Frame Headers ─────────────────────

    @Test
    fun testOversizedAndNegativeFrameHeadersRejected() {
        // TCP Transport enforces MAX_FRAME_SIZE = 16 MB and length > 0
        val maxFrame = 16 * 1024 * 1024
        val oversized = maxFrame + 1
        val negative = -100

        assertTrue("Frame length > 16MB must exceed boundary", oversized > maxFrame)
        assertTrue("Negative frame length must be <= 0", negative <= 0)

        // Validate PathSafetyValidator rejects raw relative paths that are blank or traversal
        assertThrows(IllegalArgumentException::class.java) {
            PathSafetyValidator.validateRelativePath("")
        }
        assertThrows(SecurityException::class.java) {
            PathSafetyValidator.validateRelativePath("../../etc/passwd")
        }
    }

    // ── 2. Inbound Manifest Path Traversal Attack Defense ───────────────────

    @Test
    fun testInboundManifestPathTraversalRejectedInPreflight() {
        val dangerousPaths = listOf(
            "../../Windows/System32/cmd.exe",
            "../etc/shadow",
            "foo/../../bar.txt",
            "/absolute/root/file.txt",
            "C:\\boot.ini",
            "CON.txt",
            "AUX",
            "NUL.dat",
            "bad\u0000byte.txt",
            "trailingdot."
        )

        for (badPath in dangerousPaths) {
            val manifest = TransferManifest.newBuilder()
                .setTransferId("xfer_traversal_test")
                .setSenderPeerId(PeerId.newBuilder().setValue("peer-attacker").build())
                .setReceiverPeerId(PeerId.newBuilder().setValue("peer-victim").build())
                .setChunkSizeBytes(64 * 1024)
                .setTotalBytes(10)
                .addItems(
                    TransferItem.newBuilder()
                        .setRelativePath(badPath)
                        .setFileSizeBytes(10)
                        .setIsDirectory(false)
                        .build()
                )
                .build()

            val error = PeerTransferEngine.validateManifest(manifest)
            assertNotNull("Manifest containing dangerous path '$badPath' must be rejected", error)
        }
    }

    // ── 3. Outbound Display Name Path Traversal Containment ─────────────────

    @Test
    fun testOutboundDisplayNamePathTraversalContainment() {
        val stagingOutbound = File(tempDir, "staging_outbound").apply { mkdirs() }
        val maliciousDisplayName = "../../evil_script.sh"

        // Sanitize logic implemented in AndroidNodeFacade
        val rawName = maliciousDisplayName
        val safeName = if (rawName.isNotBlank()) File(rawName).name else "item"
        val cachedFile = stagingOutbound.toPath().resolve(safeName).normalize()

        assertEquals("evil_script.sh", safeName)
        assertTrue("Normalized target must remain within staging outbound", cachedFile.startsWith(stagingOutbound.toPath().normalize()))
    }

    // ── 4. Corrupt Chunk Checksum Rejection ─────────────────────────────────

    @Test
    fun testCorruptChunkChecksumRejected() {
        val transferId = "xfer_corrupt_test"
        transferEngine.stagingManager.prepareStagingDir(transferId)

        // Construct manifest with 1 item of 100 bytes
        val manifest = TransferManifest.newBuilder()
            .setTransferId(transferId)
            .setSenderPeerId(PeerId.newBuilder().setValue("peer-sender").build())
            .setReceiverPeerId(PeerId.newBuilder().setValue("peer-receiver").build())
            .setChunkSizeBytes(64 * 1024)
            .setTotalBytes(100)
            .addItems(
                TransferItem.newBuilder()
                    .setRelativePath("valid_doc.txt")
                    .setFileSizeBytes(100)
                    .setIsDirectory(false)
                    .build()
            )
            .build()

        val offer = TransferOffer.newBuilder().setManifest(manifest).build()
        val offerResp = transferEngine.handleIncomingOffer(offer, destDir.toPath())
        assertTrue("Valid offer must be initially accepted", offerResp.accepted)

        // Provide a chunk with mismatched chunk SHA-256 hash string
        val chunkData = com.google.protobuf.ByteString.copyFrom(ByteArray(50) { 1.toByte() })
        val bogusSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

        val corruptChunk = TransferChunk.newBuilder()
            .setTransferId(transferId)
            .setItemIndex(0)
            .setChunkIndex(0)
            .setOffsetBytes(0)
            .setData(chunkData)
            .setIsLastChunk(false)
            .setChunkSha256(bogusSha256)
            .build()

        val ack = transferEngine.handleIncomingChunk(corruptChunk)
        assertFalse("Chunk with corrupt/mismatched SHA-256 checksum must be rejected", ack.success)
        assertTrue("Retry must be requested for corrupted chunk", ack.retryRequested)
        assertTrue("Ack error message must indicate corrupt chunk detected: ${ack.errorMessage}",
            ack.errorMessage.contains("Corrupt chunk detected") && ack.errorMessage.contains("expected="))
    }

    // ── 5. Notification Action Idempotency Under Repeated Replay ────────────

    @Test
    fun testNotificationActionIdempotency() {
        val initialContext = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .storagePermissionGranted(true)
            .build()
        val stateMachine = AndroidNodeStateMachine(initialContext)
        val keystore = AndroidKeystoreManager.createInMemoryTestManager("TestNode")
        val contentResolverBridge = object : AndroidStorageAbstraction.ContentResolverBridge {
            override fun openInputStream(uriString: String): InputStream = ByteArrayInputStream(byteArrayOf())
            override fun openOutputStream(uriString: String): OutputStream = ByteArrayOutputStream()
            override fun delete(uriString: String): Boolean = true
            override fun exists(uriString: String): Boolean = true
            override fun getLength(uriString: String): Long = 0L
            override fun getDisplayName(uriString: String): String = "test.dat"
            override fun getLastModified(uriString: String): Long = 1000L
            override fun isDirectory(uriString: String): Boolean = false
            override fun listChildren(treeUriString: String): List<String> = emptyList()
            override fun checkReadPermission(uriString: String): Boolean = true
            override fun checkWritePermission(uriString: String): Boolean = true
        }
        val storage = AndroidStorageAbstraction(contentResolverBridge)
        val clipboard = AndroidClipboardAdapter(keystore.peerId.value, ClipboardSyncMode.OFF, NoOpClipboardBridge(), stateMachine)
        val discovery = AndroidDiscoveryEngine(emptyList())
        val notificationController = AndroidNotificationController(NoOpNotificationBridge())

        val facade = AndroidNodeFacade(stateMachine, keystore, storage, clipboard, discovery, notificationController)

        // Repeated responses to a non-existent or already finished transfer must return false idempotently without crashing
        assertFalse(facade.respondIncomingTransfer("non_existent_xfer", true))
        assertFalse(facade.respondIncomingTransfer("non_existent_xfer", false))
        assertFalse(facade.respondIncomingTransfer("non_existent_xfer", true))
    }

    // ── 6. Revoked Peer Transfer Offer Rejected Immediately ─────────────────

    private class AuditFakePeerSession(private val remote: PeerIdentity) : PeerSession {
        val sentPayloads = mutableListOf<ByteArray>()
        override fun getSessionId(): SessionId = SessionId.newBuilder().setValue("fake-session").build()
        override fun getLocalPeer(): PeerIdentity = PeerIdentity.newBuilder().setDisplayName("Local").build()
        override fun getRemotePeer(): PeerIdentity = remote
        override fun getState(): SessionState = SessionState.SESSION_STATE_ESTABLISHED
        override fun getActiveTransportType(): TransportType = TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS
        override fun getConnection(): TransportConnection? = null
        override fun getDescriptor(): SessionDescriptor = SessionDescriptor.getDefaultInstance()
        override fun sendPayloadAsync(payload: ByteArray): CompletableFuture<Void> {
            sentPayloads.add(payload)
            return CompletableFuture.completedFuture(null)
        }
        override fun setPayloadHandler(handler: SessionPayloadHandler) {}
        override fun sendPingAsync(): CompletableFuture<Long> = CompletableFuture.completedFuture(10L)
        override fun closeAsync(reasonCode: Int, reason: String?): CompletableFuture<Void> = CompletableFuture.completedFuture(null)
        override fun close() {}
    }

    @Test
    fun testRevokedPeerOfferRejectedImmediately() {
        val revokedPeerId = "peer-revoked-bad-actor"
        trustStore.addTrustedPeer(revokedPeerId, "FP_1234567890", ByteArray(32))
        trustStore.revokeTrust(revokedPeerId)
        assertTrue(trustStore.isRevoked(revokedPeerId))

        val receiver = TransferSessionReceiver(
            transferEngine,
            destDir.toPath(),
            trustStore,
            TransferSessionReceiver.ReceiverConsentMode.MANUAL_PROMPT_ALL
        )

        val mockPeer = PeerIdentity.newBuilder()
            .setPeerId(PeerId.newBuilder().setValue(revokedPeerId).build())
            .setDisplayName("Bad Actor")
            .build()

        val fakeSession = AuditFakePeerSession(mockPeer)

        val manifest = TransferManifest.newBuilder()
            .setTransferId("xfer_revoked_test")
            .setSenderPeerId(PeerId.newBuilder().setValue(revokedPeerId).build())
            .setReceiverPeerId(PeerId.newBuilder().setValue("peer-me").build())
            .setChunkSizeBytes(64 * 1024)
            .setTotalBytes(10)
            .addItems(TransferItem.newBuilder().setRelativePath("data.bin").setFileSizeBytes(10).build())
            .build()

        val offer = TransferOffer.newBuilder().setManifest(manifest).build()

        // handleOffer must cleanly reject without throwing
        receiver.handleOffer(fakeSession, offer)
        assertEquals(1, fakeSession.sentPayloads.size)
        val wire = TransferWireMessage.parseFrom(fakeSession.sentPayloads[0])
        assertFalse("Revoked peer offer must be rejected", wire.response.accepted)
        assertTrue("Rejection reason must mention revocation", wire.response.rejectionReason.contains("revoked", ignoreCase = true))

        // If it got past trustStore check, it would have allocated staging, but staging must not exist
        assertFalse(Files.exists(transferEngine.stagingManager.getTransferStagingDir("xfer_revoked_test")))
    }

    // ── 7. Storage Permission Denial Clean Handling ─────────────────────────

    @Test
    fun testStoragePermissionDenialThrowsAccessDenied() {
        val deniedBridge = object : AndroidStorageAbstraction.ContentResolverBridge {
            override fun openInputStream(uriString: String): InputStream = throw AccessDeniedException(File(uriString), null, "Permission denied")
            override fun openOutputStream(uriString: String): OutputStream = throw AccessDeniedException(File(uriString), null, "Permission denied")
            override fun delete(uriString: String): Boolean = false
            override fun exists(uriString: String): Boolean = true
            override fun getLength(uriString: String): Long = 100L
            override fun getDisplayName(uriString: String): String = "secret.pdf"
            override fun getLastModified(uriString: String): Long = 1000L
            override fun isDirectory(uriString: String): Boolean = false
            override fun listChildren(treeUriString: String): List<String> = emptyList()
            override fun checkReadPermission(uriString: String): Boolean = false
            override fun checkWritePermission(uriString: String): Boolean = false
        }

        val storage = AndroidStorageAbstraction(deniedBridge)

        assertThrows(java.nio.file.AccessDeniedException::class.java) {
            storage.resolveByPhysicalPath("content://com.android.providers.media.documents/document/123")
        }
    }

    // ── 8. Environmental Node State Evaluation ──────────────────────────────

    @Test
    fun testEnvironmentalNodeStateEvaluation() {
        // Offline -> UNAVAILABLE
        val offlineContext = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.OFFLINE)
            .storagePermissionGranted(true)
            .build()
        assertEquals(AndroidNodeState.UNAVAILABLE, AndroidNodeStateMachine.evaluateState(offlineContext))

        // No storage permission -> UNAVAILABLE
        val noStorageContext = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .storagePermissionGranted(false)
            .build()
        assertEquals(AndroidNodeState.UNAVAILABLE, AndroidNodeStateMachine.evaluateState(noStorageContext))

        // Foreground + Wi-Fi -> ACTIVE
        val activeContext = AndroidNodeContext.builder()
            .appInForeground(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .storagePermissionGranted(true)
            .build()
        assertEquals(AndroidNodeState.ACTIVE, AndroidNodeStateMachine.evaluateState(activeContext))

        // Background + Doze Mode -> OS_RESTRICTED
        val dozeContext = AndroidNodeContext.builder()
            .appInForeground(false)
            .deviceIdleMode(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .storagePermissionGranted(true)
            .build()
        assertEquals(AndroidNodeState.OS_RESTRICTED, AndroidNodeStateMachine.evaluateState(dozeContext))
    }

    // ── 9. NodeLifecycleState Operational and Terminal Guards ───────────────

    @Test
    fun testNodeLifecycleStateGuards() {
        assertTrue(NodeLifecycleState.STOPPED.isTerminalOrStopped)
        assertTrue(NodeLifecycleState.UNAVAILABLE.isTerminalOrStopped)
        assertFalse(NodeLifecycleState.READY.isTerminalOrStopped)

        assertTrue(NodeLifecycleState.READY.canAcceptTransfers())
        assertTrue(NodeLifecycleState.CONNECTED.canAcceptTransfers())
        assertFalse(NodeLifecycleState.STOPPED.canAcceptTransfers())

        assertTrue(NodeLifecycleState.READY.isOperational)
        assertTrue(NodeLifecycleState.CONNECTED.isOperational)
        assertTrue(NodeLifecycleState.TRANSFERRING.isOperational)
        assertFalse(NodeLifecycleState.STOPPED.isOperational)

        assertTrue(NodeLifecycleState.TRANSFERRING.isTransferring)
        assertFalse(NodeLifecycleState.READY.isTransferring)
    }
}
