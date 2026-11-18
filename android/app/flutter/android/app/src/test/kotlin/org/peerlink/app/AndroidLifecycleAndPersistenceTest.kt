package org.peerlink.app

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.peerlink.app.service.PeerLinkForegroundService
import org.peerlink.core.access.PathSandboxValidator
import org.peerlink.core.access.SafeDestinationHandler
import org.peerlink.core.operation.*
import java.io.File

/**
 * Task 4: Android Lifecycle, Resilience and Persistent Transfer Correctness.
 * Tests operation state invariants, recovery from failure, corrupted payload rejection,
 * preflight destination validation, and foreground execution contracts.
 */
class AndroidLifecycleAndPersistenceTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    @Test
    fun testAuthoritativeOperationJournalTransitionsAndInvariants() {
        val journal = InMemoryOperationJournal()
        val opId = "op_send_999"
        val idempotencyKey = "idem_tx_42"

        // 1. Register new operation in CREATED state
        val record = OperationRecord.create(
            opId,
            OperationIntent.SEND,
            "peer_sender",
            listOf("doc1.pdf"),
            idempotencyKey
        )
        journal.recordOperation(record)

        val retrieved = journal.getOperation(opId).orElseThrow()
        assertEquals(OperationState.CREATED, retrieved.state)
        assertEquals(opId, retrieved.operationId)

        // 2. Authoritative state progression
        journal.updateState(opId, OperationState.VALIDATED)
        journal.updateState(opId, OperationState.AUTHORIZED)
        journal.updateState(opId, OperationState.EXECUTING)
        journal.recordJournalStage(opId, JournalStage.EXECUTE)

        val executing = journal.getOperation(opId).orElseThrow()
        assertEquals(OperationState.EXECUTING, executing.state)
        assertEquals(JournalStage.EXECUTE, journal.getStage(opId))

        // Advance to terminal state COMMITTED
        journal.updateState(opId, OperationState.COMMITTED)
        journal.recordJournalStage(opId, JournalStage.COMMIT)
        assertEquals(OperationState.COMMITTED, journal.getOperation(opId).orElseThrow().state)

        // 3. Invariant: Illegal state transition from terminal state COMMITTED -> EXECUTING must fail
        assertThrows(IllegalStateTransitionException::class.java) {
            journal.updateState(opId, OperationState.EXECUTING)
        }

        // 4. Invariant: Duplicate idempotency key must be strictly rejected
        val duplicateRecord = OperationRecord.create(
            "op_send_1000",
            OperationIntent.SEND,
            "peer_sender",
            listOf("doc2.pdf"),
            idempotencyKey
        )
        assertThrows(DuplicateOperationException::class.java) {
            journal.recordOperation(duplicateRecord)
        }

        // 5. Rule 9: Interrupted in-flight operations must transition to OUTCOME_UNKNOWN, refusing blind replay
        val interruptedOpId = "op_interrupted_555"
        val interruptedRecord = OperationRecord.create(
            interruptedOpId,
            OperationIntent.SEND,
            "peer_sender",
            listOf("data.bin"),
            "idem_interrupted_555"
        )
        journal.recordOperation(interruptedRecord)
        journal.updateState(interruptedOpId, OperationState.EXECUTING)

        journal.markInterruptedOperationsUnknown("Simulated Android process termination during socket transfer")
        val recovered = journal.getOperation(interruptedOpId).orElseThrow()
        assertEquals(OperationState.OUTCOME_UNKNOWN, recovered.state)
        assertTrue(recovered.state.isTerminal)
    }

    @Test
    fun testDestinationSafeCommitRefusesUnverifiedOrCorruptedData() {
        val destDir = tempFolder.newFolder("dest_storage")
        val targetFileName = "financial_statement.pdf"
        val expectedSha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" // sha256 of empty bytes

        val handler = SafeDestinationHandler(destDir.toPath())

        // Verification must throw SecurityException when content hash does not match expected SHA-256
        assertThrows(SecurityException::class.java) {
            handler.commitContent(targetFileName, "CORRUPTED BYTES IN FLIGHT".toByteArray(), expectedSha256)
        }

        // The final destination file MUST NOT exist
        val finalDestinationFile = File(destDir, targetFileName)
        assertFalse("Target destination file must not be committed or visible to user", finalDestinationFile.exists())
    }

    @Test
    fun testDestinationSandboxEscapesProhibited() {
        val destDir = tempFolder.newFolder("sandbox_root")
        val handler = SafeDestinationHandler(destDir.toPath())

        // Path traversal escape attempt must throw PathTraversalException
        assertThrows(PathSandboxValidator.PathTraversalException::class.java) {
            handler.commitContent("../../../system_compromise.txt", "MALICIOUS".toByteArray(), null)
        }
    }

    @Test
    fun testForegroundServiceContractConstants() {
        // Enforces Android 14+ foreground service contract requirements
        assertEquals("org.peerlink.app.service.START", PeerLinkForegroundService.ACTION_START)
        assertEquals("org.peerlink.app.service.STOP", PeerLinkForegroundService.ACTION_STOP)
        assertEquals(9001, PeerLinkForegroundService.NOTIFICATION_ID)
    }
}
