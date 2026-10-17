package org.peerlink.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.peerlink.core.android.AndroidSqliteOperationJournal
import org.peerlink.core.android.AndroidStartupRecoveryManager
import org.peerlink.core.operation.*
import org.peerlink.core.transfer.FileManifestBuilder
import java.io.File
import java.nio.file.Files
import java.util.UUID

/**
 * Android Instrumented Test for durable Android SQLite Operation Journal,
 * process restart persistence, and startup crash recovery conforming to Rule 9.
 *
 * Runs on real Android OS / emulator runtime via connectedDebugAndroidTest.
 */
@RunWith(AndroidJUnit4::class)
class AndroidSqliteJournalInstrumentedTest {

    private lateinit var dbName: String
    private lateinit var testStagingDir: File
    private lateinit var testDestDir: File

    @Before
    fun setUp() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val timestamp = System.currentTimeMillis()
        dbName = "test_ops_$timestamp.db"
        testStagingDir = File(context.filesDir, "staging_$timestamp").apply { mkdirs() }
        testDestDir = File(context.filesDir, "dest_$timestamp").apply { mkdirs() }
    }

    @Test
    fun testJournalPersistenceAcrossProcessRecreation() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        // Process instance 1: record operations
        var journal: AndroidSqliteOperationJournal? = AndroidSqliteOperationJournal(context, dbName)
        val opId1 = "op_send_001"
        val idempKey1 = "idemp_test_001"
        val record1 = OperationRecord.create(opId1, OperationIntent.SEND, "peer_sender_1", listOf("file1.dat"), idempKey1)

        journal!!.recordOperation(record1)
        journal.recordJournalStage(opId1, JournalStage.EXECUTE)
        journal.updateState(opId1, OperationState.EXECUTING)
        journal.appendNote(opId1, "Started transfer chunks 1-5")

        // Simulate abrupt process termination: close journal and release memory
        journal.close()
        journal = null
        System.gc()

        // Process instance 2: restart process with fresh journal instance pointing to same DB
        val restartedJournal = AndroidSqliteOperationJournal(context, dbName)
        try {
            val retrieved = restartedJournal.getOperation(opId1)
            assertTrue("Operation record must survive process termination", retrieved.isPresent)
            assertEquals(opId1, retrieved.get().operationId)
            assertEquals(OperationState.EXECUTING, retrieved.get().state)
            assertEquals(OperationIntent.SEND, retrieved.get().intent)

            val meta = restartedJournal.getOperationMetadata(opId1)
            assertTrue(meta.isPresent)
            assertEquals(JournalStage.EXECUTE, meta.get().stage())
            assertTrue(meta.get().notes().contains("Started transfer chunks 1-5"))
        } finally {
            restartedJournal.close()
        }
    }

    @Test
    fun testIdempotencyUniquenessAndTerminalStateProtection() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val journal = AndroidSqliteOperationJournal(context, dbName)

        try {
            val opId1 = "op_idemp_1"
            val idempKey = "same_idemp_key"
            val rec1 = OperationRecord.create(opId1, OperationIntent.SEND, "peer_a", listOf("f1"), idempKey)
            journal.recordOperation(rec1)

            // Duplicate submission with DIFFERENT operation_id must throw DuplicateOperationException
            val opId2 = "op_idemp_2"
            val rec2 = OperationRecord.create(opId2, OperationIntent.SEND, "peer_a", listOf("f1"), idempKey)
            try {
                journal.recordOperation(rec2)
                fail("Expected DuplicateOperationException on duplicate idempotency_key")
            } catch (e: DuplicateOperationException) {
                println("Successfully caught duplicate idempotency submission: ${e.message}")
            }

            // Terminal state guard: transition to COMMITTED
            journal.updateState(opId1, OperationState.COMMITTED)
            assertEquals(OperationState.COMMITTED, journal.getOperation(opId1).get().state)

            // Attempting to move from terminal COMMITTED back to EXECUTING must be rejected
            try {
                journal.updateState(opId1, OperationState.EXECUTING)
                fail("Expected IllegalStateTransitionException on terminal state modification")
            } catch (e: IllegalStateTransitionException) {
                println("Successfully caught illegal terminal state transition: ${e.message}")
            }
        } finally {
            journal.close()
        }
    }

    @Test
    fun testStartupRecoveryInterruptedChunkWritingInfersUnknownOutcomeWithoutBlindReplay() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        // Process 1: In-flight chunk writing before sudden death
        var journal: AndroidSqliteOperationJournal? = AndroidSqliteOperationJournal(context, dbName)
        val opId = "op_mid_flight_chunk"
        val rec = OperationRecord.create(opId, OperationIntent.SEND, "peer_sender", listOf("chunked.bin"), "idemp_chunk_1")
        journal!!.recordOperation(rec)
        journal.recordJournalStage(opId, JournalStage.EXECUTE)
        journal.updateState(opId, OperationState.EXECUTING)
        journal.setOperationMetadata(opId, testStagingDir.absolutePath + "/partial.bin", testDestDir.absolutePath + "/chunked.bin", "expected_hash_abc", 10000)
        journal.updateTransferredBytes(opId, 4096)

        // Abrupt kill
        journal.close()
        journal = null

        // Process 2: Startup recovery
        val restartedJournal = AndroidSqliteOperationJournal(context, dbName)
        try {
            val recoveryManager = AndroidStartupRecoveryManager(restartedJournal)
            val summary = recoveryManager.reconcileOnStartup(testStagingDir.toPath(), testDestDir.toPath())

            assertEquals(1, summary.totalIncompleteFound())
            assertEquals(1, summary.unknownOutcomeMarked())
            assertEquals(0, summary.committedRecovered())

            val recoveredOp = restartedJournal.getOperation(opId).get()
            assertEquals("Interrupted chunk write must infer OUTCOME_UNKNOWN on restart", OperationState.OUTCOME_UNKNOWN, recoveredOp.state)

            val recoveryEntries = restartedJournal.listRecoveryEntries(opId)
            assertFalse(recoveryEntries.isEmpty())
            assertEquals("OUTCOME_UNKNOWN_EXECUTION_INTERRUPTED", recoveryEntries[0]["decision"])

            // Repeated recovery must be idempotent
            val summary2 = recoveryManager.reconcileOnStartup(testStagingDir.toPath(), testDestDir.toPath())
            assertEquals(0, summary2.totalIncompleteFound()) // Already terminal
        } finally {
            restartedJournal.close()
        }
    }

    @Test
    fun testStartupRecoveryInterruptedCommitReconciledAgainstDestinationTruth() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        val opId = "op_commit_crash"
        val expectedData = "Confirmed file content committed before kill".toByteArray(Charsets.UTF_8)
        val expectedSha256 = FileManifestBuilder.calculateSha256Hex(expectedData)
        val destFile = File(testDestDir, "final_data.txt")

        // Case A: Destination file WAS committed to disk before process died
        Files.write(destFile.toPath(), expectedData)

        var journal: AndroidSqliteOperationJournal? = AndroidSqliteOperationJournal(context, dbName)
        val rec = OperationRecord.create(opId, OperationIntent.SEND, "peer_sender", listOf("final_data.txt"), "idemp_commit_1")
        journal!!.recordOperation(rec)
        journal.recordJournalStage(opId, JournalStage.COMMIT)
        journal.updateState(opId, OperationState.EXECUTING)
        journal.setOperationMetadata(opId, testStagingDir.absolutePath + "/final_data.txt", destFile.absolutePath, expectedSha256, expectedData.size.toLong())

        // Abrupt kill
        journal.close()
        journal = null

        // Restart recovery
        val restartedJournal = AndroidSqliteOperationJournal(context, dbName)
        try {
            val recoveryManager = AndroidStartupRecoveryManager(restartedJournal)
            val summary = recoveryManager.reconcileOnStartup(testStagingDir.toPath(), testDestDir.toPath())

            assertEquals(1, summary.totalIncompleteFound())
            assertEquals(1, summary.committedRecovered())
            assertEquals(0, summary.unknownOutcomeMarked())

            val reconciledOp = restartedJournal.getOperation(opId).get()
            assertEquals("Intact destination file matching hash must be safely COMMITTED", OperationState.COMMITTED, reconciledOp.state)
        } finally {
            restartedJournal.close()
        }
    }

    @Test
    fun testStartupRecoveryMissingDestinationTransitionsToUnknownWithoutReplay() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        val opId = "op_missing_dest"
        val expectedSha256 = "deadbeefcafebabe12345678"
        val missingDestFile = File(testDestDir, "missing_dest.txt")

        var journal: AndroidSqliteOperationJournal? = AndroidSqliteOperationJournal(context, dbName)
        val rec = OperationRecord.create(opId, OperationIntent.SEND, "peer_sender", listOf("missing_dest.txt"), "idemp_missing_1")
        journal!!.recordOperation(rec)
        journal.recordJournalStage(opId, JournalStage.COMMIT)
        journal.updateState(opId, OperationState.EXECUTING)
        journal.setOperationMetadata(opId, testStagingDir.absolutePath + "/staging.txt", missingDestFile.absolutePath, expectedSha256, 5000)

        // Kill
        journal.close()
        journal = null

        // Restart recovery
        val restartedJournal = AndroidSqliteOperationJournal(context, dbName)
        try {
            val recoveryManager = AndroidStartupRecoveryManager(restartedJournal)
            val summary = recoveryManager.reconcileOnStartup(testStagingDir.toPath(), testDestDir.toPath())

            assertEquals(1, summary.totalIncompleteFound())
            assertEquals(0, summary.committedRecovered())
            assertEquals(1, summary.unknownOutcomeMarked())

            val reconciledOp = restartedJournal.getOperation(opId).get()
            assertEquals("Missing destination file must transition to OUTCOME_UNKNOWN without destructive replay",
                OperationState.OUTCOME_UNKNOWN, reconciledOp.state)
        } finally {
            restartedJournal.close()
        }
    }

    @Test
    fun testGenuinelyIncompleteTransferPreservedForResume() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val opId = "op_resumable_incomplete"
        val stagingFile = File(testStagingDir, "partial_transfer.part")
        val partialBytes = ByteArray(8192) { 0x55 }
        Files.write(stagingFile.toPath(), partialBytes)

        var journal: AndroidSqliteOperationJournal? = AndroidSqliteOperationJournal(context, dbName)
        val rec = OperationRecord.create(opId, OperationIntent.SEND, "peer_sender", listOf("partial_transfer"), "idemp_resume_1")
        journal!!.recordOperation(rec)
        journal.recordJournalStage(opId, JournalStage.EXECUTE)
        journal.updateState(opId, OperationState.EXECUTING)
        journal.setOperationMetadata(opId, stagingFile.absolutePath, testDestDir.absolutePath + "/final.bin", "expected_full_hash", 16384)
        journal.updateTransferredBytes(opId, 8192)

        // Kill process abruptly
        journal.close()
        journal = null

        // Restart recovery
        val restartedJournal = AndroidSqliteOperationJournal(context, dbName)
        try {
            val recoveryManager = AndroidStartupRecoveryManager(restartedJournal)
            val summary = recoveryManager.reconcileOnStartup(testStagingDir.toPath(), testDestDir.toPath())

            assertEquals(1, summary.totalIncompleteFound())
            assertEquals("Valid staged bytes must be preserved for resume", 1, summary.resumablePreserved())
            assertEquals(0, summary.committedRecovered())

            val reconciledOp = restartedJournal.getOperation(opId).get()
            assertEquals("Incomplete transfer with valid staging must transition to WAITING (resumable)",
                OperationState.WAITING, reconciledOp.state)

            // Critical: Staging file MUST NOT be deleted
            assertTrue("Staging file must remain intact for transfer resume", stagingFile.exists())
            assertEquals(8192L, stagingFile.length())
        } finally {
            restartedJournal.close()
        }
    }

    @Test
    fun testCorruptedStagingContentQuarantinedWithoutLossOfEvidence() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val opId = "op_corrupted_staging"
        val stagingFile = File(testStagingDir, "corrupted_chunk.part")
        Files.write(stagingFile.toPath(), byteArrayOf(0x00, 0x01, 0x02))

        // Create corruption marker
        val corruptMarker = File(testStagingDir, "corrupted_chunk.part.corrupt_marker")
        Files.write(corruptMarker.toPath(), "BAD_CHECKSUM".toByteArray())

        var journal: AndroidSqliteOperationJournal? = AndroidSqliteOperationJournal(context, dbName)
        val rec = OperationRecord.create(opId, OperationIntent.SEND, "peer_sender", listOf("corrupted_chunk"), "idemp_corrupt_1")
        journal!!.recordOperation(rec)
        journal.recordJournalStage(opId, JournalStage.EXECUTE)
        journal.updateState(opId, OperationState.EXECUTING)
        journal.setOperationMetadata(opId, stagingFile.absolutePath, testDestDir.absolutePath + "/final.bin", "expected_hash", 1000)

        // Kill process
        journal.close()
        journal = null

        // Restart recovery
        val restartedJournal = AndroidSqliteOperationJournal(context, dbName)
        try {
            val recoveryManager = AndroidStartupRecoveryManager(restartedJournal)
            val summary = recoveryManager.reconcileOnStartup(testStagingDir.toPath(), testDestDir.toPath())

            assertEquals(1, summary.totalIncompleteFound())
            assertEquals(1, summary.corruptedQuarantined())
            assertEquals(1, summary.unknownOutcomeMarked())

            val reconciledOp = restartedJournal.getOperation(opId).get()
            assertEquals("Corrupted staging must transition to OUTCOME_UNKNOWN",
                OperationState.OUTCOME_UNKNOWN, reconciledOp.state)

            // Quarantined file exists with .corrupt extension for forensic analysis
            val quarantinedFile = File(testStagingDir, "corrupted_chunk.part.corrupt")
            assertTrue("Corrupted staging file must be quarantined as .corrupt", quarantinedFile.exists())
            assertFalse("Original unquarantined staging file must be removed from active path", stagingFile.exists())
        } finally {
            restartedJournal.close()
        }
    }

    @Test
    fun testUncertainFinalizationPartialDestinationQuarantined() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val opId = "op_uncertain_partial_commit"
        val expectedHash = "abc123expectedfullhash456789"
        val destFile = File(testDestDir, "partial_commit.bin")
        // Destination has partial content written before crash
        Files.write(destFile.toPath(), "PARTIAL_DESTINATION_DATA".toByteArray())

        var journal: AndroidSqliteOperationJournal? = AndroidSqliteOperationJournal(context, dbName)
        val rec = OperationRecord.create(opId, OperationIntent.SEND, "peer_sender", listOf("partial_commit.bin"), "idemp_uncertain_1")
        journal!!.recordOperation(rec)
        journal.recordJournalStage(opId, JournalStage.COMMIT)
        journal.updateState(opId, OperationState.EXECUTING)
        journal.setOperationMetadata(opId, testStagingDir.absolutePath + "/part.tmp", destFile.absolutePath, expectedHash, 50000)

        // Kill process
        journal.close()
        journal = null

        // Restart recovery
        val restartedJournal = AndroidSqliteOperationJournal(context, dbName)
        try {
            val recoveryManager = AndroidStartupRecoveryManager(restartedJournal)
            val summary = recoveryManager.reconcileOnStartup(testStagingDir.toPath(), testDestDir.toPath())

            assertEquals(1, summary.totalIncompleteFound())
            assertEquals(1, summary.unknownOutcomeMarked())
            assertEquals(0, summary.committedRecovered())

            val reconciledOp = restartedJournal.getOperation(opId).get()
            assertEquals("Uncertain commit outcome must be marked OUTCOME_UNKNOWN",
                OperationState.OUTCOME_UNKNOWN, reconciledOp.state)

            // Partial file is quarantined as .partial_uncertain to prevent corruption
            val quarantinedDest = File(testDestDir, "partial_commit.bin.partial_uncertain")
            assertTrue("Partial destination file must be quarantined as .partial_uncertain", quarantinedDest.exists())
        } finally {
            restartedJournal.close()
        }
    }
}
