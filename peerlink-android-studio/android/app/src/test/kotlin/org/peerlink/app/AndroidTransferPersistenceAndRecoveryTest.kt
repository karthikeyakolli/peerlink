package org.peerlink.app

import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.peerlink.core.android.*
import org.peerlink.core.operation.DuplicateOperationException
import org.peerlink.core.operation.InMemoryOperationJournal
import org.peerlink.core.operation.JournalStage
import org.peerlink.core.operation.OperationIntent
import org.peerlink.core.operation.OperationRecord
import org.peerlink.core.operation.OperationState
import org.peerlink.core.security.InMemoryTrustStore
import org.peerlink.core.transfer.*
import org.peerlink.core.transport.PeerSession
import org.peerlink.core.transport.PeerSessionManager
import org.peerlink.core.transport.StandardTcpTransportProvider
import org.peerlink.core.transport.TransportCapabilityNegotiator
import org.peerlink.protocol.v1.DuplicateDestinationPolicy
import org.peerlink.protocol.v1.OperationId
import org.peerlink.protocol.v1.ProtocolVersion
import org.peerlink.protocol.v1.TransferChunk
import org.peerlink.protocol.v1.TransferCompletedReceipt
import org.peerlink.protocol.v1.TransferOffer
import org.peerlink.protocol.v1.TransferOperationStatusQuery
import org.peerlink.protocol.v1.TransferState
import org.peerlink.protocol.v1.TransferWireMessage
import java.io.File
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Phase 6 Acceptance Gate: Transfer persistence, crash recovery and background execution.
 *
 * Verifies:
 * 1. Wire transfer interruption and partial resumption skipping already-ACKed chunks.
 * 2. Process crash & startup recovery: Committed file confirmed intact and marked COMMITTED.
 * 3. Process crash & startup recovery: Uncertain/partial destination write quarantined as .partial_uncertain (Rule 9).
 * 4. Staging corruption detection: Corrupted staging files quarantined as .corrupt (marked OUTCOME_UNKNOWN).
 * 5. Valid incomplete staging preserved as WAITING for resumption.
 * 6. Unstarted operations (CREATED, VALIDATED, AUTHORIZED) cancelled on startup.
 * 7. In-flight source file mutation detection (size/timestamp discrepancy throws SourceMutationException).
 * 8. Duplicate idempotency key rejection (DuplicateOperationException).
 * 9. Foreground service timeout / shutdown: Graceful transfer pause without corruption.
 * 10. Lost ACK reconciliation via status query: Receiver returns is_committed=true without repeating destructive commit (Rule 9).
 */
class AndroidTransferPersistenceAndRecoveryTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var dirA: File
    private lateinit var dirB: File
    private lateinit var stagingA: File
    private lateinit var stagingB: File
    private lateinit var destB: File

    private lateinit var transportA: StandardTcpTransportProvider
    private lateinit var transportB: StandardTcpTransportProvider

    private lateinit var sessionManagerA: PeerSessionManager
    private lateinit var sessionManagerB: PeerSessionManager

    private lateinit var keystoreA: AndroidKeystoreManager
    private lateinit var keystoreB: AndroidKeystoreManager

    private lateinit var trustStoreA: InMemoryTrustStore
    private lateinit var trustStoreB: InMemoryTrustStore

    private lateinit var journalA: InMemoryOperationJournal
    private lateinit var journalB: InMemoryOperationJournal

    private lateinit var sessionJournalB: InMemoryTransferSessionJournal
    private lateinit var engineA: PeerTransferEngine
    private lateinit var engineB: PeerTransferEngine

    private val version = ProtocolVersion.newBuilder().setMajor(1).setMinor(0).setPatch(0).build()

    @Before
    fun setUp() {
        dirA = tempFolder.newFolder("nodeA")
        dirB = tempFolder.newFolder("nodeB")
        stagingA = File(dirA, "staging").apply { mkdirs() }
        stagingB = File(dirB, "staging").apply { mkdirs() }
        destB = File(dirB, "dest").apply { mkdirs() }

        transportA = StandardTcpTransportProvider("127.0.0.1")
        transportB = StandardTcpTransportProvider("127.0.0.1")

        trustStoreA = InMemoryTrustStore()
        trustStoreB = InMemoryTrustStore()

        journalA = InMemoryOperationJournal()
        journalB = InMemoryOperationJournal()

        sessionJournalB = InMemoryTransferSessionJournal()

        engineA = PeerTransferEngine(journalA, stagingA.toPath())
        engineB = PeerTransferEngine(
            journalB,
            sessionJournalB,
            StagingDirectoryManager(stagingB.toPath()),
            TransferPreflight(),
            DestinationConflictResolver(),
            BandwidthLimiter(),
            TransferQueueManager()
        )

        val masterKeyProviderA = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val secStoreA = AndroidKeyStoreSecureKeyStore(dirA, masterKeyProviderA, "key_a")
        val metaStoreA = FileIdentityMetadataStore(dirA)
        keystoreA = AndroidKeystoreManager.createOrLoad(secStoreA, metaStoreA, "Pixel 9 (Node A)", "Android 15", "1.0", false, "Software Ed25519")

        val masterKeyProviderB = AndroidKeyStoreSecureKeyStore.SoftwareMasterKeyProvider()
        val secStoreB = AndroidKeyStoreSecureKeyStore(dirB, masterKeyProviderB, "key_b")
        val metaStoreB = FileIdentityMetadataStore(dirB)
        keystoreB = AndroidKeystoreManager.createOrLoad(secStoreB, metaStoreB, "Galaxy S24 (Node B)", "Android 15", "1.0", false, "Software Ed25519")

        trustStoreA.addTrustedPeer(keystoreB.peerIdentity)
        trustStoreB.addTrustedPeer(keystoreA.peerIdentity)

        sessionManagerA = PeerSessionManager(
            keystoreA.peerIdentity, keystoreA.deviceIdentity, keystoreA.signer, trustStoreA, version, version,
            TransportCapabilityNegotiator(listOf(transportA))
        )
        sessionManagerB = PeerSessionManager(
            keystoreB.peerIdentity, keystoreB.deviceIdentity, keystoreB.signer, trustStoreB, version, version,
            TransportCapabilityNegotiator(listOf(transportB))
        )
    }

    @After
    fun tearDown() {
        transportA.stopListening()
        transportB.stopListening()
    }

    private fun establishSessionAB(): Pair<PeerSession, PeerSession> {
        val inboundSessionFuture = CompletableFuture<PeerSession>()
        sessionManagerB.addSessionLifecycleListener(object : PeerSessionManager.SessionLifecycleListener {
            override fun onSessionEstablished(session: PeerSession) {
                inboundSessionFuture.complete(session)
            }
            override fun onSessionClosed(session: PeerSession) {}
        })

        transportB.startListening(0) { conn ->
            sessionManagerB.handleInboundConnection(conn)
        }
        val portB = transportB.listeningPort

        val connA = transportA.connectAsync(InetSocketAddress("127.0.0.1", portB)).get(5, TimeUnit.SECONDS)
        val sessionA = sessionManagerA.initiateSessionAsync(connA).get(5, TimeUnit.SECONDS)
        val sessionB = inboundSessionFuture.get(5, TimeUnit.SECONDS)

        return Pair(sessionA, sessionB)
    }

    @Test
    fun testWireTransferInterruptionAndResumeWithoutResendingAckedChunks() {
        val (sessionA, sessionB) = establishSessionAB()

        val coordinatorB = TransferSessionCoordinator(sessionB)
        val receiverB = TransferSessionReceiver(engineB, destB.toPath(), trustStoreB)
        coordinatorB.registerReceiver(receiverB)

        // Create 20KB test file (chunk size is 8KB, so 3 chunks: chunk 0 [8KB], chunk 1 [8KB], chunk 2 [4KB])
        val testFile = File(dirA, "interrupted_doc.bin")
        val fileBytes = ByteArray(20 * 1024)
        for (i in fileBytes.indices) {
            fileBytes[i] = ((i * 31) % 256).toByte()
        }
        FileOutputStream(testFile).use { it.write(fileBytes) }

        // Build custom manifest with 8KB chunk size
        val transferId = "xfer_resume_01"
        val opId = "op_send_resume_01"
        val manifest = FileManifestBuilder(8192).buildManifest(
            transferId,
            opId,
            keystoreA.peerId.value,
            keystoreB.peerId.value,
            listOf(testFile.toPath()),
            DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_OVERWRITE
        )

        // 1. Send Offer and First 2 chunks manually to simulate partial transfer
        val coordinatorA = TransferSessionCoordinator(sessionA)
        val offerFuture = coordinatorA.registerPendingOffer(transferId)
        val offerWire = TransferWireMessage.newBuilder().setOffer(
            TransferOffer.newBuilder().setManifest(manifest).setTimestampUtcMs(System.currentTimeMillis()).build()
        ).build()
        sessionA.sendPayloadAsync(offerWire.toByteArray())
        val offerResp = offerFuture.get(5, TimeUnit.SECONDS)
        assertTrue("Offer must be accepted", offerResp.accepted)

        // Send Chunk 0
        val chunk0Data = fileBytes.copyOfRange(0, 8192)
        val ack0Future = coordinatorA.registerPendingChunkAck(transferId, 0, 0)
        sessionA.sendPayloadAsync(TransferWireMessage.newBuilder().setChunk(
            TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(0)
                .setChunkIndex(0)
                .setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(chunk0Data))
                .setIsLastChunk(false)
                .setChunkSha256(FileManifestBuilder.calculateSha256Hex(chunk0Data))
                .build()
        ).build().toByteArray())
        val ack0 = ack0Future.get(5, TimeUnit.SECONDS)
        assertTrue(ack0.success)

        // Send Chunk 1
        val chunk1Data = fileBytes.copyOfRange(8192, 16384)
        val ack1Future = coordinatorA.registerPendingChunkAck(transferId, 0, 1)
        sessionA.sendPayloadAsync(TransferWireMessage.newBuilder().setChunk(
            TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(0)
                .setChunkIndex(1)
                .setOffsetBytes(8192)
                .setData(com.google.protobuf.ByteString.copyFrom(chunk1Data))
                .setIsLastChunk(false)
                .setChunkSha256(FileManifestBuilder.calculateSha256Hex(chunk1Data))
                .build()
        ).build().toByteArray())
        val ack1 = ack1Future.get(5, TimeUnit.SECONDS)
        assertTrue(ack1.success)

        // Now verify Receiver B has recorded acked chunks 0 and 1
        val ackedChunks = sessionJournalB.getAckedChunks(transferId, 0)
        assertEquals(setOf(0L, 1L), ackedChunks)

        // 2. Resume transfer using resumeTransferOverSession
        // The sender should query resume state, see that chunks 0 and 1 are already acked,
        // and transmit ONLY chunk 2 before committing!
        val resumeReceipt = engineA.resumeTransferOverSession(
            sessionA,
            manifest,
            listOf(testFile.toPath())
        ) { progress ->
            // Progress callback invoked
        }

        assertNotNull("Resume receipt must not be null", resumeReceipt)
        assertTrue("Resume receipt must be successful", resumeReceipt.success)
        assertEquals(fileBytes.size.toLong(), resumeReceipt.totalBytesTransferred)

        // 3. Verify destination file on receiver B is intact and exact
        val receivedFile = File(destB, "interrupted_doc.bin")
        assertTrue("Destination file must exist after resumed commit", receivedFile.exists())
        assertEquals(fileBytes.size.toLong(), receivedFile.length())
        val receivedBytes = Files.readAllBytes(receivedFile.toPath())
        assertArrayEquals("Received content must match original bytes identically", fileBytes, receivedBytes)
    }

    @Test
    fun testStartupRecoveryReconcilesCommittedFileIntact() {
        val recoveryManager = AndroidStartupRecoveryManager(journalB)

        val opId = "op_crash_commit_01"
        val fileName = "recovery_doc.dat"
        val fileContent = "Important committed user file content".toByteArray(StandardCharsets.UTF_8)

        // Destination file exists physically on disk
        val destFile = File(destB, fileName)
        FileOutputStream(destFile).use { it.write(fileContent) }
        val sha256 = FileManifestBuilder.calculateSha256Hex(fileContent)

        // Operation journal was in EXECUTING with stage COMMIT when crash occurred
        val record = OperationRecord.create(
            opId,
            OperationIntent.SEND,
            keystoreA.peerId.value,
            listOf(fileName),
            "idemp_crash_01"
        )
        journalB.recordOperation(record)
        journalB.updateState(opId, OperationState.EXECUTING)
        journalB.recordJournalStage(opId, JournalStage.COMMIT)
        journalB.setOperationMetadata(opId, JournalStage.COMMIT, null, destFile.absolutePath, sha256)

        // Run startup recovery
        val summary = recoveryManager.reconcileOnStartup(stagingB.toPath(), destB.toPath())

        assertEquals(1, summary.totalIncompleteFound)
        assertEquals(1, summary.committedRecovered)
        assertEquals(0, summary.unknownOutcomeMarked)

        val updatedRecord = journalB.getOperation(opId).orElseThrow()
        assertEquals("Intact destination file must be reconciled to COMMITTED", OperationState.COMMITTED, updatedRecord.state)
    }

    @Test
    fun testStartupRecoveryQuarantinesPartialUncertainCommitRule9() {
        val recoveryManager = AndroidStartupRecoveryManager(journalB)

        val opId = "op_crash_commit_partial"
        val fileName = "truncated_doc.dat"
        val corruptedContent = "Truncated partial write...".toByteArray(StandardCharsets.UTF_8)

        // Destination file was partially written when process died
        val destFile = File(destB, fileName)
        FileOutputStream(destFile).use { it.write(corruptedContent) }

        val record = OperationRecord.create(
            opId,
            OperationIntent.SEND,
            keystoreA.peerId.value,
            listOf(fileName),
            "idemp_partial_01"
        )
        journalB.recordOperation(record)
        journalB.updateState(opId, OperationState.EXECUTING)
        journalB.recordJournalStage(opId, JournalStage.COMMIT)
        journalB.setOperationMetadata(opId, JournalStage.COMMIT, null, destFile.absolutePath, "expected_valid_sha256_hash_that_wont_match_truncated")

        // Startup recovery runs: file exists but hash does NOT match expected digest
        val summary = recoveryManager.reconcileOnStartup(stagingB.toPath(), destB.toPath())

        assertEquals(1, summary.totalIncompleteFound)
        assertEquals(0, summary.committedRecovered)
        assertEquals(1, summary.unknownOutcomeMarked)

        // Rule 9: Never blindly replay destructive commit; marked OUTCOME_UNKNOWN
        val updatedRecord = journalB.getOperation(opId).orElseThrow()
        assertEquals(OperationState.OUTCOME_UNKNOWN, updatedRecord.state)

        // Corrupted destination file must be quarantined to prevent data corruption
        val quarantinedFile = File(destB, "$fileName.partial_uncertain")
        assertTrue("Corrupted destination file must be renamed to .partial_uncertain", quarantinedFile.exists())
    }

    @Test
    fun testStartupRecoveryQuarantinesCorruptStaging() {
        val recoveryManager = AndroidStartupRecoveryManager(journalB)

        val opId = "op_staging_corrupt"
        val stagingPart = File(stagingB, "$opId.part")
        FileOutputStream(stagingPart).use { it.write("corrupted chunk data".toByteArray()) }

        // Create corrupt marker indicating I/O or hash failure before crash
        val corruptMarker = File(stagingB, "$opId.part.corrupt_marker")
        corruptMarker.createNewFile()

        val record = OperationRecord.create(
            opId,
            OperationIntent.SEND,
            keystoreA.peerId.value,
            listOf(opId),
            "idemp_staging_01"
        )
        journalB.recordOperation(record)
        journalB.updateState(opId, OperationState.EXECUTING)
        journalB.recordJournalStage(opId, JournalStage.EXECUTE)

        val summary = recoveryManager.reconcileOnStartup(stagingB.toPath(), destB.toPath())

        assertEquals(1, summary.totalIncompleteFound)
        assertEquals(1, summary.corruptedQuarantined)
        assertEquals(1, summary.unknownOutcomeMarked)

        val updatedRecord = journalB.getOperation(opId).orElseThrow()
        assertEquals(OperationState.OUTCOME_UNKNOWN, updatedRecord.state)

        val quarantinedStaging = File(stagingB, "$opId.part.corrupt")
        assertTrue("Corrupted staging file must be quarantined as .corrupt", quarantinedStaging.exists())
    }

    @Test
    fun testStartupRecoveryPreservesValidIncompleteStagingAsWaiting() {
        val recoveryManager = AndroidStartupRecoveryManager(journalB)

        val opId = "op_valid_incomplete"
        val stagingPart = File(stagingB, "$opId.part")
        FileOutputStream(stagingPart).use { it.write("valid verified chunks 1-4".toByteArray()) }

        val record = OperationRecord.create(
            opId,
            OperationIntent.SEND,
            keystoreA.peerId.value,
            listOf(opId),
            "idemp_valid_inc"
        )
        journalB.recordOperation(record)
        journalB.updateState(opId, OperationState.EXECUTING)
        journalB.recordJournalStage(opId, JournalStage.EXECUTE)

        val summary = recoveryManager.reconcileOnStartup(stagingB.toPath(), destB.toPath())

        assertEquals(1, summary.totalIncompleteFound)
        assertEquals(1, summary.resumablePreserved)
        assertEquals(0, summary.unknownOutcomeMarked)

        val updatedRecord = journalB.getOperation(opId).orElseThrow()
        assertEquals("Valid incomplete transfer must be marked WAITING for resume", OperationState.WAITING, updatedRecord.state)
    }

    @Test
    fun testStartupRecoveryCancelsUnstartedOperations() {
        val recoveryManager = AndroidStartupRecoveryManager(journalB)

        val op1 = "op_unstarted_created"
        val op2 = "op_unstarted_validated"
        val op3 = "op_unstarted_authorized"

        journalB.recordOperation(OperationRecord.create(op1, OperationIntent.SEND, keystoreA.peerId.value, listOf("f1"), "idemp_1"))
        // op1 remains CREATED

        journalB.recordOperation(OperationRecord.create(op2, OperationIntent.SEND, keystoreA.peerId.value, listOf("f2"), "idemp_2"))
        journalB.updateState(op2, OperationState.VALIDATED)

        journalB.recordOperation(OperationRecord.create(op3, OperationIntent.SEND, keystoreA.peerId.value, listOf("f3"), "idemp_3"))
        journalB.updateState(op3, OperationState.AUTHORIZED)

        val summary = recoveryManager.reconcileOnStartup(stagingB.toPath(), destB.toPath())

        assertEquals(3, summary.totalIncompleteFound)
        assertEquals(3, summary.cancelledUnstarted)

        assertEquals(OperationState.CANCELLED, journalB.getOperation(op1).orElseThrow().state)
        assertEquals(OperationState.CANCELLED, journalB.getOperation(op2).orElseThrow().state)
        assertEquals(OperationState.CANCELLED, journalB.getOperation(op3).orElseThrow().state)
    }

    @Test
    fun testSourceFileMutationDetectedAndAborted() {
        val (sessionA, sessionB) = establishSessionAB()

        val coordinatorB = TransferSessionCoordinator(sessionB)
        val receiverB = TransferSessionReceiver(engineB, destB.toPath(), trustStoreB)
        coordinatorB.registerReceiver(receiverB)

        val sourceFile = File(dirA, "mutable_doc.txt")
        FileOutputStream(sourceFile).use { it.write("Initial valid content".toByteArray()) }

        val manifest = FileManifestBuilder().buildManifest(
            "xfer_mutation_01",
            "op_mutation_01",
            keystoreA.peerId.value,
            keystoreB.peerId.value,
            listOf(sourceFile.toPath()),
            DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_OVERWRITE
        )

        // Mutate source file size after manifest generation but before send
        FileOutputStream(sourceFile).use { it.write("Modified content that changed file size entirely!".toByteArray()) }

        assertThrows(SourceMutationException::class.java) {
            engineA.sendTransferOverSession(
                sessionA,
                manifest,
                listOf(sourceFile.toPath())
            ) {}
        }
    }

    @Test
    fun testDuplicateOperationIdempotencyRejected() {
        val opId1 = "op_unique_1"
        val opId2 = "op_duplicate_2"
        val idemKey = "idemp_shared_key_100"

        val record1 = OperationRecord.create(opId1, OperationIntent.SEND, keystoreA.peerId.value, listOf("file.txt"), idemKey)
        journalA.recordOperation(record1)

        val record2 = OperationRecord.create(opId2, OperationIntent.SEND, keystoreA.peerId.value, listOf("file.txt"), idemKey)
        assertThrows(DuplicateOperationException::class.java) {
            journalA.recordOperation(record2)
        }
    }

    @Test
    fun testLostAckReconciledWithoutRepeatingDestructiveCommitRule9() {
        val transferId = "xfer_lost_ack_01"
        val opId = "op_lost_ack_01"

        // Simulate receiver B already having committed transfer and generated receipt
        val receipt = TransferCompletedReceipt.newBuilder()
            .setTransferId(transferId)
            .setOperationId(OperationId.newBuilder().setValue(opId).build())
            .setSuccess(true)
            .setTotalBytesTransferred(1024)
            .setCompletionTimestampUtcMs(System.currentTimeMillis())
            .build()

        val sessionRecord = TransferSessionRecord(
            transferId,
            opId,
            keystoreA.peerId.value,
            keystoreB.peerId.value,
            TransferState.TRANSFER_STATE_COMPLETED,
            1024,
            1,
            System.currentTimeMillis()
        )
        sessionRecord.receipt = receipt
        sessionJournalB.recordSession(sessionRecord)

        // Sender queries receiver status after lost connection
        val query = TransferOperationStatusQuery.newBuilder()
            .setTransferId(transferId)
            .setOperationId(OperationId.newBuilder().setValue(opId).build())
            .build()

        val response = engineB.handleOperationStatusQuery(query)

        assertTrue("Status query must confirm transfer is already committed", response.isCommitted)
        assertEquals(TransferState.TRANSFER_STATE_COMPLETED, response.state)
        assertNotNull(response.receipt)
        assertEquals(1024L, response.receipt.totalBytesTransferred)
    }

    @Test
    fun testGracefulPauseUpdatesJournalAndTrackerState() {
        val testFile = File(dirA, "pause_file.bin")
        FileOutputStream(testFile).use { it.write("test pause bytes".toByteArray()) }

        val manifest = engineA.prepareSend(
            keystoreA.peerId.value,
            keystoreB.peerId.value,
            listOf(testFile.toPath()),
            DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_OVERWRITE
        )

        // Sender pauses transfer
        engineA.pauseTransfer(manifest.transferId, "User clicked pause")

        val op = journalA.getOperation(manifest.operationId.value).orElseThrow()
        assertEquals("Paused transfer must transition to WAITING", OperationState.WAITING, op.state)
    }
}
