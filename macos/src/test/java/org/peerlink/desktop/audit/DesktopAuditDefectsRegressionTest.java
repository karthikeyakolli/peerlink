package org.peerlink.desktop.audit;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.operation.OperationIntent;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.peerlink.desktop.ipc.LocalTokenAuthInterceptor;
import org.peerlink.desktop.runtime.NodeConfiguration;
import org.peerlink.desktop.storage.LocalSqliteStorage;
import org.peerlink.desktop.storage.ObjectIndexRepository;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.SQLException;
import java.util.List;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

public class DesktopAuditDefectsRegressionTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("Audit Defect 5: NodeConfiguration must regenerate secure random token if token file is empty")
    void testEmptyTokenFileRegeneratesSecureToken() throws IOException {
        Path dataDir = tempDir.resolve("node_data");
        Files.createDirectories(dataDir);
        Path tokenFile = dataDir.resolve("ipc_auth.token");
        // Create 0-byte or whitespace empty token file
        Files.writeString(tokenFile, "   \n");

        NodeConfiguration config = NodeConfiguration.loadOrCreate(dataDir, 50051);

        assertNotNull(config.getIpcAuthToken());
        assertFalse(config.getIpcAuthToken().isBlank(), "Auth token must never be empty or blank!");
        assertTrue(config.getIpcAuthToken().length() >= 32, "Auth token must have sufficient entropy!");
    }

    @Test
    @DisplayName("Audit Defect 5b: LocalTokenAuthInterceptor must reject null or blank expectedToken in constructor")
    void testLocalTokenAuthInterceptorRejectsBlankToken() {
        assertThrows(IllegalArgumentException.class, () -> new LocalTokenAuthInterceptor(null));
        assertThrows(IllegalArgumentException.class, () -> new LocalTokenAuthInterceptor(""));
        assertThrows(IllegalArgumentException.class, () -> new LocalTokenAuthInterceptor("   "));
    }

    @Test
    @DisplayName("Audit Defect 7: LocalSqliteStorage and ObjectIndexRepository concurrent execution safety")
    void testConcurrentStorageAndRepositoryAccess() throws SQLException, InterruptedException, ExecutionException {
        Path dbPath = tempDir.resolve("concurrent_test.db");
        LocalSqliteStorage storage = new LocalSqliteStorage(dbPath);
        ObjectIndexRepository repo = storage.getObjectIndex();

        ExecutorService executor = Executors.newFixedThreadPool(4);
        try {
            int iterations = 100;

            Callable<Void> task1 = () -> {
                for (int i = 0; i < iterations; i++) {
                    storage.recordOperation(OperationRecord.create(
                            "op_" + i, OperationIntent.SEND, "peer_1", List.of("obj_1"), "idemp_" + i
                    ));
                }
                return null;
            };

            Callable<Void> task2 = () -> {
                for (int i = 0; i < iterations; i++) {
                    repo.upsertObject(new ObjectIndexRepository.ObjectIndexEntry(
                            "obj_" + i, "hash_" + i, "/path/" + i, 1024L, "text/plain",
                            System.currentTimeMillis(), System.currentTimeMillis(),
                            ObjectIndexRepository.IndexState.ACTIVE
                    ));
                }
                return null;
            };

            Future<Void> f1 = executor.submit(task1);
            Future<Void> f2 = executor.submit(task2);

            f1.get();
            f2.get();
        } finally {
            executor.shutdown();
            assertTrue(executor.awaitTermination(5, TimeUnit.SECONDS));
            storage.close();
        }
    }
}
