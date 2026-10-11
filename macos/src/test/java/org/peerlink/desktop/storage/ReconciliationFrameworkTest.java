package org.peerlink.desktop.storage;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.operation.OperationIntent;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;

import java.nio.file.Path;
import java.sql.SQLException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class ReconciliationFrameworkTest {

    @TempDir
    Path tempDir;

    private LocalSqliteStorage storage;
    private ReconciliationFramework framework;

    @BeforeEach
    void setUp() throws SQLException {
        Path dbPath = tempDir.resolve("reconciliation_test.db");
        storage = new LocalSqliteStorage(dbPath);
        framework = new ReconciliationFramework(storage);
    }

    @AfterEach
    void tearDown() {
        if (storage != null) {
            storage.close();
        }
    }

    @Test
    void testReconcileUnknownOperationsPendingClassification() {
        long now = System.currentTimeMillis();
        OperationRecord op = new OperationRecord(
                "op-unknown-1",
                OperationIntent.SYNC,
                "peer-alice",
                List.of("obj-10"),
                OperationState.OUTCOME_UNKNOWN,
                "idemp-recon-1",
                now,
                now
        );
        storage.recordOperation(op);

        List<ReconciliationFramework.ReconciliationResult> results = framework.reconcileUnknownOperations();
        assertEquals(1, results.size());
        assertEquals("op-unknown-1", results.get(0).operationId());
        assertEquals(ReconciliationFramework.ReconciliationDecision.RECONCILIATION_PENDING, results.get(0).decision());
    }
}
