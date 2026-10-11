package org.peerlink.desktop.ipc;

import io.grpc.*;
import io.grpc.stub.StreamObserver;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.desktop.runtime.NodeConfiguration;
import org.peerlink.protocol.v1.*;

import java.nio.file.Path;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.*;

public class DesktopNodeIpcSessionSecurityTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("IPC: Authenticate exchange issues ephemeral session token, replacing reusable boot secret")
    void testEphemeralSessionTokenIssuedOnAuthenticate() throws Exception {
        String bootToken = "my-secure-boot-secret-token-abcdef123456789";
        DesktopLocalNodeServiceImpl service = new DesktopLocalNodeServiceImpl(bootToken, "peer_test", 50051);

        AuthenticateIpcRequest request = AuthenticateIpcRequest.newBuilder()
                .setAuthToken(bootToken)
                .setClientPid(12345)
                .setClientVersion(DesktopLocalNodeServiceImpl.NODE_VERSION)
                .build();

        CompletableFuture<AuthenticateIpcResponse> future = new CompletableFuture<>();
        service.authenticate(request, new StreamObserver<AuthenticateIpcResponse>() {
            @Override
            public void onNext(AuthenticateIpcResponse value) { future.complete(value); }
            @Override
            public void onError(Throwable t) { future.completeExceptionally(t); }
            @Override
            public void onCompleted() {}
        });

        AuthenticateIpcResponse response = future.get(3, TimeUnit.SECONDS);
        assertTrue(response.getAuthenticated());
        assertTrue(response.getIsCompatible());

        String sessionToken = response.getSessionToken();
        assertNotNull(sessionToken);
        assertTrue(sessionToken.startsWith("sess_"), "Session token must be an ephemeral session identifier");
        assertNotEquals(bootToken, sessionToken, "Session token must NOT expose the reusable boot secret");
        assertTrue(service.isSessionValid(sessionToken), "Issued session token must be currently valid");

        service.close();
    }

    @Test
    @DisplayName("IPC: Session token is accepted by LocalTokenAuthInterceptor")
    void testSessionTokenAcceptedByInterceptor() {
        DesktopLocalNodeServiceImpl service = new DesktopLocalNodeServiceImpl("boot-secret", "peer_test", 50051);
        String sessionToken = service.createCustomSession(999, 60_000);

        LocalTokenAuthInterceptor interceptor = new LocalTokenAuthInterceptor(
                "boot-secret", service::isSessionValid
        );

        Metadata headers = new Metadata();
        headers.put(LocalTokenAuthInterceptor.AUTH_HEADER, sessionToken);

        AtomicBoolean nextCalled = new AtomicBoolean(false);
        ServerCall<String, String> call = new NoopServerCall<>("peerlink.v1.DesktopLocalNodeService/GetStatus");

        interceptor.interceptCall(call, headers, (c, h) -> {
            nextCalled.set(true);
            return new ServerCall.Listener<>() {};
        });

        assertTrue(nextCalled.get(), "Valid session token must pass interceptor authentication");
        service.close();
    }

    @Test
    @DisplayName("IPC: Unauthenticated call without header is rejected even on loopback")
    void testUnauthenticatedCallRejected() {
        LocalTokenAuthInterceptor interceptor = new LocalTokenAuthInterceptor("boot-secret");

        Metadata emptyHeaders = new Metadata();
        NoopServerCall<String, String> call = new NoopServerCall<>("peerlink.v1.DesktopLocalNodeService/GetStatus");

        interceptor.interceptCall(call, emptyHeaders, (c, h) -> {
            fail("Next handler should not be called for unauthenticated request");
            return new ServerCall.Listener<>() {};
        });

        assertTrue(call.isClosed());
        assertEquals(Status.Code.UNAUTHENTICATED, call.getClosedStatus().getCode());
    }

    @Test
    @DisplayName("IPC: Expired session token is rejected")
    void testExpiredSessionTokenRejected() throws InterruptedException {
        DesktopLocalNodeServiceImpl service = new DesktopLocalNodeServiceImpl("boot-secret", "peer_test", 50051);
        // Create session with 10ms lifetime
        String shortLivedSession = service.createCustomSession(1001, 10);
        assertTrue(service.isSessionValid(shortLivedSession));

        // Sleep to let session expire
        Thread.sleep(30);

        assertFalse(service.isSessionValid(shortLivedSession), "Expired session must no longer be valid");

        LocalTokenAuthInterceptor interceptor = new LocalTokenAuthInterceptor(
                service::isSessionValid
        );

        Metadata headers = new Metadata();
        headers.put(LocalTokenAuthInterceptor.AUTH_HEADER, shortLivedSession);

        NoopServerCall<String, String> call = new NoopServerCall<>("peerlink.v1.DesktopLocalNodeService/GetStatus");
        interceptor.interceptCall(call, headers, (c, h) -> {
            fail("Next handler should not be called for expired session");
            return new ServerCall.Listener<>() {};
        });

        assertTrue(call.isClosed());
        assertEquals(Status.Code.UNAUTHENTICATED, call.getClosedStatus().getCode());

        service.close();
    }

    @Test
    @DisplayName("IPC: Explicit session revocation invalidates token immediately")
    void testSessionRevocation() {
        DesktopLocalNodeServiceImpl service = new DesktopLocalNodeServiceImpl("boot-secret", "peer_test", 50051);
        String sessionToken = service.createCustomSession(2002, 60_000);
        assertTrue(service.isSessionValid(sessionToken));

        boolean revoked = service.revokeSession(sessionToken);
        assertTrue(revoked);
        assertFalse(service.isSessionValid(sessionToken), "Revoked session must be immediately rejected");

        service.close();
    }

    @Test
    @DisplayName("IPC: Session rotation replaces old token with new token")
    void testSessionRotation() {
        DesktopLocalNodeServiceImpl service = new DesktopLocalNodeServiceImpl("boot-secret", "peer_test", 50051);
        String oldToken = service.createCustomSession(3003, 60_000);
        assertTrue(service.isSessionValid(oldToken));

        String newToken = service.rotateSession(oldToken);
        assertNotNull(newToken);
        assertNotEquals(oldToken, newToken);

        assertFalse(service.isSessionValid(oldToken), "Old token must be invalid after rotation");
        assertTrue(service.isSessionValid(newToken), "New rotated token must be valid");

        service.close();
    }

    @Test
    @DisplayName("Security: NodeConfiguration redacts plaintext auth token in toString and logs")
    void testTokenNotExposedInLogsOrToString() throws Exception {
        NodeConfiguration config = NodeConfiguration.loadOrCreate(tempDir.resolve("conf_data"), 50051);
        String rawToken = config.getIpcAuthToken();
        String stringRep = config.toString();

        assertFalse(stringRep.contains(rawToken), "NodeConfiguration.toString() must NOT contain raw token");
        assertTrue(stringRep.contains(config.getMaskedIpcToken()), "Must display masked representation");
    }

    /**
     * Minimal test server call capturing close status.
     */
    private static class NoopServerCall<ReqT, RespT> extends ServerCall<ReqT, RespT> {
        private final MethodDescriptor<ReqT, RespT> methodDescriptor;
        private boolean closed = false;
        private Status closedStatus;

        @SuppressWarnings("unchecked")
        NoopServerCall(String fullMethodName) {
            this.methodDescriptor = MethodDescriptor.<ReqT, RespT>newBuilder()
                    .setType(MethodDescriptor.MethodType.UNARY)
                    .setFullMethodName(fullMethodName)
                    .setRequestMarshaller(new NoopMarshaller<>())
                    .setResponseMarshaller(new NoopMarshaller<>())
                    .build();
        }

        @Override
        public void request(int numMessages) {}

        @Override
        public void sendHeaders(Metadata headers) {}

        @Override
        public void sendMessage(RespT message) {}

        @Override
        public void close(Status status, Metadata trailers) {
            this.closed = true;
            this.closedStatus = status;
        }

        @Override
        public boolean isCancelled() { return false; }

        @Override
        public MethodDescriptor<ReqT, RespT> getMethodDescriptor() { return methodDescriptor; }

        public boolean isClosed() { return closed; }
        public Status getClosedStatus() { return closedStatus; }
    }

    private static class NoopMarshaller<T> implements MethodDescriptor.Marshaller<T> {
        @Override
        public java.io.InputStream stream(T value) { return new java.io.ByteArrayInputStream(new byte[0]); }
        @Override
        public T parse(java.io.InputStream stream) { return null; }
    }
}
