package org.peerlink.desktop.chaos;

import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.Metadata;
import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.desktop.ipc.LocalTokenAuthInterceptor;
import org.peerlink.desktop.runtime.DesktopNodeDaemon;
import org.peerlink.desktop.runtime.NodeConfiguration;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.nio.file.Path;
import java.sql.SQLException;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Desktop Local Node Chaos and Process Recovery Integration Tests.
 */
public class DesktopChaosIntegrationTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("Process Chaos: Local Node abrupt crash and restart recovery")
    void testLocalNodeAbruptCrashAndRestart() throws IOException, SQLException {
        int port = 54399;
        NodeConfiguration config = NodeConfiguration.loadOrCreate(tempDir.resolve("daemon_data"), port);
        DesktopNodeDaemon daemon = new DesktopNodeDaemon(config);

        // 1. Initial Start
        daemon.start();
        assertTrue(daemon.isRunning());
        assertTrue(daemon.isHealthy());

        // 2. Abrupt Stop (simulating SIGKILL / crash)
        daemon.stop();
        assertFalse(daemon.isRunning());

        // 3. Restart
        DesktopNodeDaemon restartedDaemon = new DesktopNodeDaemon(config);
        restartedDaemon.start();
        assertTrue(restartedDaemon.isRunning());
        assertTrue(restartedDaemon.isHealthy());

        // Verify recovery report ran
        assertNotNull(restartedDaemon.getLastRecoveryReport());
        assertNotNull(restartedDaemon.getLastRecoveryReport().summary());

        restartedDaemon.stop();
    }

    @Test
    @DisplayName("Security Chaos: Local IPC impersonation and unauthorized access rejection")
    void testLocalIpcAuthenticationChaos() throws IOException, SQLException {
        int port = 54398;
        NodeConfiguration config = NodeConfiguration.loadOrCreate(tempDir.resolve("ipc_data"), port);
        DesktopNodeDaemon daemon = new DesktopNodeDaemon(config);
        daemon.start();

        ManagedChannel channel = ManagedChannelBuilder.forAddress("127.0.0.1", port)
                .usePlaintext()
                .build();

        try {
            // Case 1: Call without authorization header -> must fail UNAUTHENTICATED
            DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub unauthStub =
                    DesktopLocalNodeServiceGrpc.newBlockingStub(channel);

            StatusRuntimeException ex1 = assertThrows(StatusRuntimeException.class, () -> {
                unauthStub.getStatus(GetNodeStatusRequest.newBuilder().setSessionToken("none").build());
            });
            assertEquals(Status.Code.UNAUTHENTICATED, ex1.getStatus().getCode());

            // Case 2: Call with wrong token -> must fail UNAUTHENTICATED
            Metadata badHeaders = new Metadata();
            badHeaders.put(LocalTokenAuthInterceptor.AUTH_HEADER, "wrong-impersonation-token-99999");
            DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub badStub =
                    DesktopLocalNodeServiceGrpc.newBlockingStub(channel)
                            .withInterceptors(io.grpc.stub.MetadataUtils.newAttachHeadersInterceptor(badHeaders));

            StatusRuntimeException ex2 = assertThrows(StatusRuntimeException.class, () -> {
                badStub.getStatus(GetNodeStatusRequest.newBuilder().build());
            });
            assertEquals(Status.Code.UNAUTHENTICATED, ex2.getStatus().getCode());

            // Case 3: Call with valid token -> must succeed
            Metadata validHeaders = new Metadata();
            validHeaders.put(LocalTokenAuthInterceptor.AUTH_HEADER, config.getIpcAuthToken());
            DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub validStub =
                    DesktopLocalNodeServiceGrpc.newBlockingStub(channel)
                            .withInterceptors(io.grpc.stub.MetadataUtils.newAttachHeadersInterceptor(validHeaders));

            GetNodeStatusResponse status = validStub.getStatus(GetNodeStatusRequest.newBuilder().build());
            assertNotNull(status);
            assertEquals(NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING, status.getStatus());
            assertEquals(daemon.getPeerId(), status.getPeerId().getValue());
        } finally {
            channel.shutdownNow();
            daemon.stop();
        }
    }
}
