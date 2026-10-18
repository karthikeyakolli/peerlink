package org.peerlink.app

import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.peerlink.core.android.*
import org.peerlink.core.android.discovery.AndroidDiscoveryEngine
import org.peerlink.core.android.discovery.TransportRouteSelector
import org.peerlink.core.collaboration.clipboard.ClipboardSyncMode
import org.peerlink.core.filesystem.PeerFileHandle
import org.peerlink.core.operation.InMemoryOperationJournal
import org.peerlink.core.operation.OperationIntent
import org.peerlink.core.operation.OperationState
import org.peerlink.core.security.InMemoryTrustStore
import org.peerlink.core.transfer.PeerTransferEngine
import org.peerlink.core.transfer.TransferSessionReceiver
import org.peerlink.core.transport.PeerSessionManager
import org.peerlink.core.transport.StandardTcpTransportProvider
import org.peerlink.core.transport.TransportCapabilityNegotiator
import org.peerlink.protocol.v1.PeerId
import org.peerlink.protocol.v1.ProtocolVersion
import java.io.*
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.security.SecureRandom
import java.util.UUID
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Phase 5 Acceptance Gate: Complete the Actual End-to-End SEND Path.
 *
 * Verifies:
 * 1. Genuine Node A -> Node B end-to-end file transfer over real TCP sockets via AndroidNodeFacade.
 * 2. 100% byte integrity verification and atomic commit to receiver destination directory.
 * 3. Multi-file transfer with atomic batch commit.
 * 4. Identical filename collision resolution (preserves existing files, writes suffixed replica).
 * 5. Inaccessible source file validation before transmission.
 * 6. Explicit receiver consent rejection flow (MANUAL_PROMPT_ALL).
 * 7. Untrusted peer rejection enforcing Rule 6 ("Never treat discovery as trust").
 */
class AndroidEndToEndSendPathTest {

    private lateinit var dirA: File
    private lateinit var dirB: File
    private lateinit var dirC: File

    private lateinit var facadeA: AndroidNodeFacade
    private lateinit var facadeB: AndroidNodeFacade
    private lateinit var facadeC: AndroidNodeFacade

    private lateinit var transportA: StandardTcpTransportProvider
    private lateinit var transportB: StandardTcpTransportProvider
    private lateinit var transportC: StandardTcpTransportProvider

    private lateinit var trustStoreA: InMemoryTrustStore
    private lateinit var trustStoreB: InMemoryTrustStore

    private lateinit var journalA: InMemoryOperationJournal
    private lateinit var journalB: InMemoryOperationJournal

    private lateinit var destDirB: File

    private val progressEventsA = CopyOnWriteArrayList<Int>()
    private val progressEventsB = CopyOnWriteArrayList<Int>()

    private class DirectFileContentResolverBridge : AndroidStorageAbstraction.ContentResolverBridge {
        override fun openInputStream(uri: String): InputStream {
            val f = parse(uri)
            if (!f.exists()) throw FileNotFoundException("File not found: $uri")
            return FileInputStream(f)
        }

        override fun openOutputStream(uri: String): OutputStream {
            val f = parse(uri)
            f.parentFile?.mkdirs()
            return FileOutputStream(f)
        }

        override fun delete(uri: String): Boolean = parse(uri).delete()
        override fun exists(uri: String): Boolean = parse(uri).exists()
        override fun getLength(uri: String): Long = parse(uri).length()
        override fun getDisplayName(uri: String): String = parse(uri).name
        override fun getLastModified(uri: String): Long = parse(uri).lastModified()
        override fun isDirectory(uri: String): Boolean = parse(uri).isDirectory
        override fun listChildren(treeUri: String): List<String> =
            parse(treeUri).listFiles()?.map { it.absolutePath } ?: emptyList()
        override fun checkReadPermission(uri: String): Boolean = true
        override fun checkWritePermission(uri: String): Boolean = true

        private fun parse(uri: String): File {
            return if (uri.startsWith("file://")) File(uri.substring(7)) else File(uri)
        }
    }

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
        val root = Files.createTempDirectory("peerlink_p5_test_").toFile()
        dirA = File(root, "node_a").apply { mkdirs() }
        dirB = File(root, "node_b").apply { mkdirs() }
        dirC = File(root, "node_c").apply { mkdirs() }
        destDirB = File(dirB, "received").apply { mkdirs() }

        val protocolVersion = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build()

        // --- Node A setup ---
        val masterKeyProviderA = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val secStoreA = AndroidKeyStoreSecureKeyStore(dirA, masterKeyProviderA, "key_a")
        val metaStoreA = FileIdentityMetadataStore(dirA)
        val keystoreA = AndroidKeystoreManager.createOrLoad(secStoreA, metaStoreA, "Pixel 9 (Node A)", "Android 15", "1.0", false, "Software Ed25519")

        val ctxA = AndroidNodeContext.builder()
            .appInForeground(true)
            .storagePermissionGranted(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .build()
        val stateMachineA = AndroidNodeStateMachine(ctxA)
        val storageA = AndroidStorageAbstraction(DirectFileContentResolverBridge())
        val clipboardA = AndroidClipboardAdapter(keystoreA.peerId.value, ClipboardSyncMode.OFF, NoOpClipboardBridge(), stateMachineA)
        val discoveryA = AndroidDiscoveryEngine(emptyList())
        val notifA = AndroidNotificationController(NoOpNotificationBridge())
        journalA = InMemoryOperationJournal()
        val engineA = PeerTransferEngine(journalA, File(dirA, "staging").apply { mkdirs() }.toPath())
        transportA = StandardTcpTransportProvider("127.0.0.1")
        trustStoreA = InMemoryTrustStore()
        val sessionManagerA = PeerSessionManager(
            keystoreA.peerIdentity, keystoreA.deviceIdentity, keystoreA.signer, trustStoreA,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transportA))
        )
        val routeSelectorA = TransportRouteSelector(transportA)

        facadeA = AndroidNodeFacade(
            stateMachineA, keystoreA, storageA, clipboardA, discoveryA, notifA, journalA, engineA,
            transportA, sessionManagerA, routeSelectorA, File(dirA, "received").apply { mkdirs() }.toPath(), trustStoreA
        )

        // --- Node B setup ---
        val masterKeyProviderB = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val secStoreB = AndroidKeyStoreSecureKeyStore(dirB, masterKeyProviderB, "key_b")
        val metaStoreB = FileIdentityMetadataStore(dirB)
        val keystoreB = AndroidKeystoreManager.createOrLoad(secStoreB, metaStoreB, "Galaxy S24 (Node B)", "Android 15", "1.0", false, "Software Ed25519")

        val ctxB = AndroidNodeContext.builder()
            .appInForeground(true)
            .storagePermissionGranted(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .build()
        val stateMachineB = AndroidNodeStateMachine(ctxB)
        val storageB = AndroidStorageAbstraction(DirectFileContentResolverBridge())
        val clipboardB = AndroidClipboardAdapter(keystoreB.peerId.value, ClipboardSyncMode.OFF, NoOpClipboardBridge(), stateMachineB)
        val discoveryB = AndroidDiscoveryEngine(emptyList())
        val notifB = AndroidNotificationController(NoOpNotificationBridge())
        journalB = InMemoryOperationJournal()
        val engineB = PeerTransferEngine(journalB, File(dirB, "staging").apply { mkdirs() }.toPath())
        transportB = StandardTcpTransportProvider("127.0.0.1")
        trustStoreB = InMemoryTrustStore()
        val sessionManagerB = PeerSessionManager(
            keystoreB.peerIdentity, keystoreB.deviceIdentity, keystoreB.signer, trustStoreB,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transportB))
        )
        val routeSelectorB = TransportRouteSelector(transportB)

        facadeB = AndroidNodeFacade(
            stateMachineB, keystoreB, storageB, clipboardB, discoveryB, notifB, journalB, engineB,
            transportB, sessionManagerB, routeSelectorB, destDirB.toPath(), trustStoreB
        )

        // Mutual trust established
        trustStoreA.addTrustedPeer(keystoreB.peerIdentity)
        trustStoreB.addTrustedPeer(keystoreA.peerIdentity)

        // --- Node C setup (Untrusted peer) ---
        val masterKeyProviderC = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val secStoreC = AndroidKeyStoreSecureKeyStore(dirC, masterKeyProviderC, "key_c")
        val metaStoreC = FileIdentityMetadataStore(dirC)
        val keystoreC = AndroidKeystoreManager.createOrLoad(secStoreC, metaStoreC, "Attacker C", "Android 15", "1.0", false, "Software Ed25519")
        val ctxC = AndroidNodeContext.builder()
            .appInForeground(true)
            .storagePermissionGranted(true)
            .networkType(AndroidNodeContext.NetworkType.WIFI)
            .build()
        val stateMachineC = AndroidNodeStateMachine(ctxC)
        val storageC = AndroidStorageAbstraction(DirectFileContentResolverBridge())
        val clipboardC = AndroidClipboardAdapter(keystoreC.peerId.value, ClipboardSyncMode.OFF, NoOpClipboardBridge(), stateMachineC)
        val discoveryC = AndroidDiscoveryEngine(emptyList())
        val notifC = AndroidNotificationController(NoOpNotificationBridge())
        val journalC = InMemoryOperationJournal()
        val engineC = PeerTransferEngine(journalC, File(dirC, "staging").apply { mkdirs() }.toPath())
        transportC = StandardTcpTransportProvider("127.0.0.1")
        val trustStoreC = InMemoryTrustStore()
        val sessionManagerC = PeerSessionManager(
            keystoreC.peerIdentity, keystoreC.deviceIdentity, keystoreC.signer, trustStoreC,
            protocolVersion, protocolVersion, TransportCapabilityNegotiator(listOf(transportC))
        )
        val routeSelectorC = TransportRouteSelector(transportC)

        facadeC = AndroidNodeFacade(
            stateMachineC, keystoreC, storageC, clipboardC, discoveryC, notifC, journalC, engineC,
            transportC, sessionManagerC, routeSelectorC, File(dirC, "received").apply { mkdirs() }.toPath(), trustStoreC
        )

        // Wire progress listener on Node A & Node B
        facadeA.addTransferListener(object : AndroidNodeFacade.TransferEventListener {
            override fun onTransferStarted(transferId: String, remotePeer: PeerId, fileName: String, totalBytes: Long) {}
            override fun onTransferProgress(transferId: String, percent: Int, transferredBytes: Long, totalBytes: Long) {
                progressEventsA.add(percent)
            }
            override fun onTransferCompleted(transferId: String, success: Boolean, errorMessage: String?) {}
        })

        facadeB.addTransferListener(object : AndroidNodeFacade.TransferEventListener {
            override fun onTransferStarted(transferId: String, remotePeer: PeerId, fileName: String, totalBytes: Long) {}
            override fun onTransferProgress(transferId: String, percent: Int, transferredBytes: Long, totalBytes: Long) {
                progressEventsB.add(percent)
            }
            override fun onTransferCompleted(transferId: String, success: Boolean, errorMessage: String?) {}
        })
    }

    @After
    fun tearDown() {
        facadeA.stop()
        facadeB.stop()
        facadeC.stop()
    }

    @Test
    fun testFullEndToEndSendFromNodeAToNodeBWithSha256VerificationAndAtomicCommit() {
        // Start Node B
        facadeB.start()
        val portB = facadeB.transportProvider.listeningPort
        assertTrue("Node B must listen on a valid TCP port", portB > 0)

        // Start Node A
        facadeA.start()

        // Discovery route registration for Node B
        facadeA.discoveryEngine.addManualPeer(facadeB.localPeerId, "Galaxy S24 (Node B)", "127.0.0.1", portB)

        // Create sample binary payload on Node A
        val payload = ByteArray(128 * 1024) // 128 KB
        SecureRandom().nextBytes(payload)
        val sourceFile = File(dirA, "payload_report.bin").apply { writeBytes(payload) }

        // Execute real transfer from Node A to Node B
        val transferId = "tx_" + UUID.randomUUID().toString().replace("-", "")
        val receiptFuture = facadeA.initiateSendAsync(facadeB.localPeerId, listOf(sourceFile.absolutePath), transferId)

        val receipt = receiptFuture.get(15, TimeUnit.SECONDS)

        assertNotNull("Receipt must not be null", receipt)
        assertTrue("Transfer must report successful execution: " + receipt.errorMessage, receipt.success)
        assertEquals("Transferred bytes must match payload size exactly", payload.size.toLong(), receipt.totalBytesTransferred)

        // Verify file presence and byte integrity on Node B filesystem
        val committedFile = File(destDirB, "payload_report.bin")
        assertTrue("Committed file must exist in Node B destination root", committedFile.exists())
        assertEquals("Committed file length must match payload", payload.size.toLong(), committedFile.length())
        assertArrayEquals("Committed bytes must match original bytes exactly (SHA-256 verified)", payload, committedFile.readBytes())

        // Verify Operation Journal on Node A
        val opA = journalA.getOperation("op_send_" + transferId.replace("tx_", ""))
        assertTrue("Node A journal must record operation", opA.isPresent)
        assertEquals("Node A journal state must be COMMITTED", OperationState.COMMITTED, opA.get().state)

        // Verify Operation Journal on Node B
        val opB = journalB.getOperation(receipt.operationId.value)
        assertTrue("Node B journal must record incoming transfer", opB.isPresent)
        assertEquals("Node B journal state must be COMMITTED", OperationState.COMMITTED, opB.get().state)

        // Verify progress tracking
        assertTrue("Node A must have received real-time progress callbacks", progressEventsA.isNotEmpty())
        assertTrue("Node B must have received real-time progress callbacks", progressEventsB.isNotEmpty())
        assertTrue("Node A final progress must reach 100%", progressEventsA.any { it == 100 })
    }

    @Test
    fun testMultiFileEndToEndTransfer() {
        facadeB.start()
        val portB = facadeB.transportProvider.listeningPort
        facadeA.start()
        facadeA.discoveryEngine.addManualPeer(facadeB.localPeerId, "Node B", "127.0.0.1", portB)

        val f1 = File(dirA, "contract_doc.pdf").apply { writeText("Sample PDF content byte payload 1") }
        val f2 = File(dirA, "photo_spec.png").apply { writeText("Sample PNG binary mockup payload 2") }
        val f3 = File(dirA, "archive_data.zip").apply { writeText("Sample ZIP compressed payload 3") }

        val totalExpectedBytes = f1.length() + f2.length() + f3.length()

        val transferId = "tx_multi_" + UUID.randomUUID().toString().replace("-", "")
        val receiptFuture = facadeA.initiateSendAsync(
            facadeB.localPeerId,
            listOf(f1.absolutePath, f2.absolutePath, f3.absolutePath),
            transferId
        )

        val receipt = receiptFuture.get(15, TimeUnit.SECONDS)

        assertTrue(receipt.success)
        assertEquals(totalExpectedBytes, receipt.totalBytesTransferred)

        val c1 = File(destDirB, "contract_doc.pdf")
        val c2 = File(destDirB, "photo_spec.png")
        val c3 = File(destDirB, "archive_data.zip")

        assertTrue("File 1 must exist on Node B", c1.exists())
        assertTrue("File 2 must exist on Node B", c2.exists())
        assertTrue("File 3 must exist on Node B", c3.exists())

        assertEquals("Sample PDF content byte payload 1", c1.readText())
        assertEquals("Sample PNG binary mockup payload 2", c2.readText())
        assertEquals("Sample ZIP compressed payload 3", c3.readText())
    }

    @Test
    fun testIdenticalFilenameCollisionRenamesSafely() {
        facadeB.start()
        val portB = facadeB.transportProvider.listeningPort
        facadeA.start()
        facadeA.discoveryEngine.addManualPeer(facadeB.localPeerId, "Node B", "127.0.0.1", portB)

        // Pre-create file with identical name on Node B
        val existing = File(destDirB, "notes.txt").apply { writeText("EXISTING USER FILE - DO NOT OVERWRITE") }

        // Node A sends new file with same name
        val incoming = File(dirA, "notes.txt").apply { writeText("NEW INCOMING NOTE") }

        val transferId = "tx_col_" + UUID.randomUUID().toString().replace("-", "")
        val receiptFuture = facadeA.initiateSendAsync(facadeB.localPeerId, listOf(incoming.absolutePath), transferId)
        val receipt = receiptFuture.get(15, TimeUnit.SECONDS)

        assertTrue(receipt.success)

        // Verify original file was preserved
        assertEquals("EXISTING USER FILE - DO NOT OVERWRITE", existing.readText())

        // Verify suffixed replica was safely created
        val suffixed = File(destDirB, "notes (1).txt")
        assertTrue("Suffixed file 'notes (1).txt' must be created safely", suffixed.exists())
        assertEquals("NEW INCOMING NOTE", suffixed.readText())
    }

    @Test
    fun testInaccessibleSourceFileFailsImmediatelyWithoutFalseClaim() {
        facadeB.start()
        facadeA.start()

        val ghostPath = File(dirA, "non_existent_ghost_file.iso").absolutePath

        assertThrows(FileNotFoundException::class.java) {
            facadeA.initiateSend(facadeB.localPeerId, listOf(ghostPath))
        }
    }

    @Test
    fun testReceiverConsentRejectionTerminatesTransferTruthfully() {
        facadeB.start()
        val portB = facadeB.transportProvider.listeningPort
        facadeA.start()
        facadeA.discoveryEngine.addManualPeer(facadeB.localPeerId, "Node B", "127.0.0.1", portB)

        // Set Node B to require explicit consent prompt for every transfer
        facadeB.receiverConsentMode = TransferSessionReceiver.ReceiverConsentMode.MANUAL_PROMPT_ALL

        // Wire incoming offer listener on Node B that explicitly REJECTS consent
        val offerReceived = AtomicBoolean(false)
        facadeB.addIncomingOfferListener { transferId, senderPeer, fileName, totalBytes, itemCount ->
            offerReceived.set(true)
            // User clicks "Decline"
            facadeB.respondIncomingTransfer(transferId, false)
        }

        val testFile = File(dirA, "consent_declined_doc.txt").apply { writeText("Secret Document") }
        val transferId = "tx_consent_" + UUID.randomUUID().toString().replace("-", "")

        val receiptFuture = facadeA.initiateSendAsync(facadeB.localPeerId, listOf(testFile.absolutePath), transferId)

        try {
            val receipt = receiptFuture.get(10, TimeUnit.SECONDS)
            assertFalse("Transfer must report failure when receiver declines consent", receipt.success)
        } catch (e: Exception) {
            // Future failing exceptionally with rejection reason is also valid and expected
            val cause = e.cause ?: e
            assertTrue("Rejection error message must reflect consent refusal",
                cause.message!!.contains("rejected") || cause.message!!.contains("DESTINATION_UNAVAILABLE"))
        }

        assertTrue("Node B must have received the offer prompt", offerReceived.get())

        // Verify that the file was NEVER committed on Node B
        val targetFile = File(destDirB, "consent_declined_doc.txt")
        assertFalse("Declined file must not be committed to destination directory", targetFile.exists())
    }

    @Test
    fun testUntrustedPeerTransferIsStrictlyRejected() {
        // Node B is running
        facadeB.start()
        val portB = facadeB.transportProvider.listeningPort

        // Attacker Node C attempts to send to Node B without pairing
        facadeC.start()
        facadeC.discoveryEngine.addManualPeer(facadeB.localPeerId, "Node B", "127.0.0.1", portB)

        val exploitFile = File(dirC, "exploit.sh").apply { writeText("echo 'untrusted'") }
        val transferId = "tx_exploit_" + UUID.randomUUID().toString().replace("-", "")

        val receiptFuture = facadeC.initiateSendAsync(facadeB.localPeerId, listOf(exploitFile.absolutePath), transferId)

        // Should fail due to untrusted peer during mutual handshake
        try {
            val receipt = receiptFuture.get(10, TimeUnit.SECONDS)
            assertFalse("Untrusted transfer must fail", receipt.success)
        } catch (e: Exception) {
            // Expected handshake rejection
            val msg = (e.cause ?: e).message ?: ""
            assertTrue("Handshake or trust failure expected", msg.contains("rejected") || msg.contains("not trusted") || msg.contains("Handshake rejected"))
        }

        assertFalse("Exploit file must not be committed", File(destDirB, "exploit.sh").exists())
    }
}
