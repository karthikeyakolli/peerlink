package org.peerlink.desktop;

import io.grpc.*;
import io.grpc.stub.StreamObserver;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.desktop.ipc.DesktopLocalNodeServiceImpl;
import org.peerlink.desktop.ipc.LocalTokenAuthInterceptor;
import org.peerlink.desktop.runtime.DesktopNodeDaemon;
import org.peerlink.desktop.runtime.NodeConfiguration;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.nio.file.Path;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

class DesktopNodeDaemonTest {

    @TempDir
    Path tempDir;

    private DesktopNodeDaemon daemon;
    private ManagedChannel channel;
    private NodeConfiguration config;
    private int port = 54321;

    @BeforeEach
    void setUp() throws IOException, SQLException {
        config = NodeConfiguration.loadOrCreate(tempDir, port);
        daemon = new DesktopNodeDaemon(config);
        daemon.start();

        channel = ManagedChannelBuilder.forAddress("127.0.0.1", port)
                .usePlaintext()
                .build();
    }

    @AfterEach
    void tearDown() {
        if (channel != null) {
            channel.shutdownNow();
        }
        if (daemon != null) {
            daemon.stop();
        }
    }

    @Test
    void testNodeLifecycleStartHealthyStopRestart() throws Exception {
        assertTrue(daemon.isRunning());
        assertTrue(daemon.isHealthy());

        // Test restart
        daemon.restart();
        assertTrue(daemon.isRunning());
        assertTrue(daemon.isHealthy());

        // Test stop
        daemon.stop();
        assertFalse(daemon.isRunning());
        assertFalse(daemon.isHealthy());
    }

    @Test
    void testAuthenticationWithValidTokenSucceeds() {
        DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub stub =
                DesktopLocalNodeServiceGrpc.newBlockingStub(channel);

        AuthenticateIpcRequest request = AuthenticateIpcRequest.newBuilder()
                .setAuthToken(config.getIpcAuthToken())
                .setClientPid(1234)
                .setClientVersion("0.1.0")
                .build();

        AuthenticateIpcResponse response = stub.authenticate(request);
        assertTrue(response.getAuthenticated());
        assertTrue(response.getIsCompatible());
        assertNotNull(response.getSessionToken());
        assertTrue(response.getSessionToken().startsWith("sess_"));
        assertEquals(DesktopLocalNodeServiceImpl.NODE_VERSION, response.getNodeVersion());
        assertFalse(response.getLocalPeerId().getValue().isEmpty());
    }

    @Test
    void testAuthenticationWithIncompatibleVersionIsRejected() {
        DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub stub =
                DesktopLocalNodeServiceGrpc.newBlockingStub(channel);

        AuthenticateIpcRequest request = AuthenticateIpcRequest.newBuilder()
                .setAuthToken(config.getIpcAuthToken())
                .setClientPid(1234)
                .setClientVersion("2.0.0-incompatible")
                .build();

        AuthenticateIpcResponse response = stub.authenticate(request);
        assertFalse(response.getAuthenticated());
        assertFalse(response.getIsCompatible());
        assertTrue(response.getErrorMessage().contains("Incompatible client version"));
    }

    @Test
    void testAuthenticationWithInvalidTokenFails() {
        DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub stub =
                DesktopLocalNodeServiceGrpc.newBlockingStub(channel);

        AuthenticateIpcRequest request = AuthenticateIpcRequest.newBuilder()
                .setAuthToken("invalid-tampered-token")
                .setClientPid(1234)
                .setClientVersion("0.1.0")
                .build();

        AuthenticateIpcResponse response = stub.authenticate(request);
        assertFalse(response.getAuthenticated());
        assertTrue(response.getIsCompatible());
        assertEquals("Invalid local IPC auth token", response.getErrorMessage());
    }

    @Test
    void testLocalhostCallWithoutTokenIsRejected() {
        DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub stub =
                DesktopLocalNodeServiceGrpc.newBlockingStub(channel);

        // Calling getStatus without header auth token must fail even on localhost
        StatusRuntimeException ex = assertThrows(StatusRuntimeException.class, () ->
                stub.getStatus(GetNodeStatusRequest.newBuilder().setSessionToken("none").build())
        );

        assertEquals(Status.Code.UNAUTHENTICATED, ex.getStatus().getCode());
    }

    @Test
    void testAuthenticatedCallWithHeaderSucceeds() {
        Metadata headers = new Metadata();
        headers.put(LocalTokenAuthInterceptor.AUTH_HEADER, config.getIpcAuthToken());

        DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub authenticatedStub =
                DesktopLocalNodeServiceGrpc.newBlockingStub(channel)
                        .withInterceptors(io.grpc.stub.MetadataUtils.newAttachHeadersInterceptor(headers));

        GetNodeStatusResponse response = authenticatedStub.getStatus(GetNodeStatusRequest.newBuilder().build());
        assertEquals(NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING, response.getStatus());
        assertEquals(daemon.getPeerId(), response.getPeerId().getValue());
        assertEquals(DesktopLocalNodeServiceImpl.NODE_VERSION, response.getNodeVersion());
        assertTrue(response.getSupportedCapabilitiesList().contains(FeatureCapability.FEATURE_TRANSFER_RESUME));
        assertTrue(response.getSupportedCapabilitiesList().contains(FeatureCapability.FEATURE_TCP_TLS));
    }

    @Test
    void testEventStreamingHeartbeat() throws Exception {
        Metadata headers = new Metadata();
        headers.put(LocalTokenAuthInterceptor.AUTH_HEADER, config.getIpcAuthToken());

        DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceStub asyncStub =
                DesktopLocalNodeServiceGrpc.newStub(channel)
                        .withInterceptors(io.grpc.stub.MetadataUtils.newAttachHeadersInterceptor(headers));

        List<NodeEvent> receivedEvents = new ArrayList<>();
        CountDownLatch latch = new CountDownLatch(2);

        asyncStub.subscribeEvents(NodeEventSubscriptionRequest.newBuilder().build(), new StreamObserver<>() {
            @Override
            public void onNext(NodeEvent event) {
                receivedEvents.add(event);
                latch.countDown();
            }

            @Override
            public void onError(Throwable t) {}

            @Override
            public void onCompleted() {}
        });

        // Wait up to 3.5 seconds to receive initial heartbeat (seq 0) + streaming heartbeat (seq 1+)
        boolean received = latch.await(3500, TimeUnit.MILLISECONDS);
        assertTrue(received, "Should have received at least 2 streaming events");
        assertTrue(receivedEvents.size() >= 2);
        assertTrue(receivedEvents.get(0).hasHeartbeat());
        assertEquals(0, receivedEvents.get(0).getHeartbeat().getSequenceNumber());
        assertEquals(NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING, receivedEvents.get(0).getHeartbeat().getStatus());
    }

    @Test
    void testReconnectionAcrossNodeRestart() throws Exception {
        Metadata headers = new Metadata();
        headers.put(LocalTokenAuthInterceptor.AUTH_HEADER, config.getIpcAuthToken());

        DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceBlockingStub authenticatedStub =
                DesktopLocalNodeServiceGrpc.newBlockingStub(channel)
                        .withInterceptors(io.grpc.stub.MetadataUtils.newAttachHeadersInterceptor(headers));

        // 1. Initial query succeeds
        GetNodeStatusResponse initialStatus = authenticatedStub.getStatus(GetNodeStatusRequest.newBuilder().build());
        assertEquals(NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING, initialStatus.getStatus());

        // 2. Restart the Node daemon process
        daemon.restart();

        // 3. Second query over the same channel succeeds (gRPC auto-reconnects to localhost)
        GetNodeStatusResponse postRestartStatus = authenticatedStub.getStatus(GetNodeStatusRequest.newBuilder().build());
        assertEquals(NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING, postRestartStatus.getStatus());
        assertEquals(daemon.getPeerId(), postRestartStatus.getPeerId().getValue());
    }
}
