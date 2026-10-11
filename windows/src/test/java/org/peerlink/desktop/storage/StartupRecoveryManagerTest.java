package org.peerlink.desktop.storage;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.event.NodeEvent;
import org.peerlink.core.event.NodeEventBus;
import org.peerlink.core.operation.OperationIntent;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;

import java.nio.file.Path;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class StartupRecoveryManagerTest {

    @TempDir
    Path tempDir;

    private LocalSqliteStorage storage;
    private NodeEventBus eventBus;
    private StartupRecoveryManager recoveryManager;
    private final List<NodeEvent> publishedEvents = new ArrayList<>();

    @BeforeEach
    void setUp() throws SQLException {
        Path dbPath = tempDir.resolve("recovery_test.db");
        storage = new LocalSqliteStorage(dbPath);
        eventBus = new NodeEventBus(Runnable::run);
        eventBus.subscribe(publishedEvents::add);
        recoveryManager = new StartupRecoveryManager(storage, eventBus);
    }

    @AfterEach
    void tearDown() {
        if (storage != null) {
            storage.close();
        }
    }

    @Test
    void testCleanStartupReport() throws StartupRecoveryManager.StartupRecoveryException {
        StartupRecoveryManager.RecoveryReport report = recoveryManager.runRecovery("Clean start");

        assertEquals(0, report.interruptedFound());
        assertEquals(0, report.markedUnknown());
        assertEquals(0, report.cancelledPreExecution());
        assertEquals(0, report.recoveryRequiredCount());
        assertEquals(0, report.totalUnknownOutcome());

        // Event should be published
        assertTrue(publishedEvents.stream().anyMatch(e -> e instanceof NodeEvent.RecoveryCompleted));
    }

    @Test
    void testCrashRecoveryMarksExecutingAsUnknownAndCancelsPreExecution() throws StartupRecoveryManager.StartupRecoveryException {
        long now = System.currentTimeMillis();

        // 1. In-flight operation that crashed during execution
        OperationRecord executingOp = new OperationRecord(
                "op-crashed-1",
                OperationIntent.SEND,
                "peer-alice",
                List.of("obj-1"),
                OperationState.EXECUTING,
                "idemp-crash-1",
                now,
                now
        );
        storage.recordOperation(executingOp);

        // 2. Pre-execution operation that was only CREATED
        OperationRecord createdOp = new OperationRecord(
                "op-created-1",
                OperationIntent.SEND,
                "peer-alice",
                List.of("obj-2"),
                OperationState.CREATED,
                "idemp-created-1",
                now,
                now
        );
        storage.recordOperation(createdOp);

        // 3. Pre-execution operation that was VALIDATED
        OperationRecord validatedOp = new OperationRecord(
                "op-val-1",
                OperationIntent.SYNC,
                "peer-bob",
                List.of("obj-3"),
                OperationState.VALIDATED,
                "idemp-val-1",
                now,
                now
        );
        storage.recordOperation(validatedOp);

        // Run recovery
        StartupRecoveryManager.RecoveryReport report = recoveryManager.runRecovery("Simulated crash restart");

        assertEquals(1, report.interruptedFound());
        assertEquals(1, report.markedUnknown());
        assertEquals(2, report.cancelledPreExecution());
        assertEquals(1, report.totalUnknownOutcome());

        // Verify crashed op is now OUTCOME_UNKNOWN (never blindly replayed)
        OperationRecord updatedCrashed = storage.getOperation("op-crashed-1").orElseThrow();
        assertEquals(OperationState.OUTCOME_UNKNOWN, updatedCrashed.getState());

        // Verify pre-execution ops are CANCELLED
        assertEquals(OperationState.CANCELLED, storage.getOperation("op-created-1").orElseThrow().getState());
        assertEquals(OperationState.CANCELLED, storage.getOperation("op-val-1").orElseThrow().getState());

        // Verify event published
        assertTrue(publishedEvents.stream().anyMatch(e -> e instanceof NodeEvent.RecoveryCompleted));
    }
}
