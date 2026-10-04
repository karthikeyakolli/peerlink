package org.peerlink.desktop.ipc;

import io.grpc.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Local IPC authentication interceptor.
 * Critical invariant: Localhost is NOT automatically trusted!
 * Any local process attempting to call protected IPC methods without a valid token is rejected.
 */
public final class LocalTokenAuthInterceptor implements ServerInterceptor {
    private static final Logger log = LoggerFactory.getLogger(LocalTokenAuthInterceptor.class);

    public static final Metadata.Key<String> AUTH_HEADER =
            Metadata.Key.of("x-peerlink-auth-token", Metadata.ASCII_STRING_MARSHALLER);

    private final String expectedToken;

    public LocalTokenAuthInterceptor(String expectedToken) {
        if (expectedToken == null || expectedToken.isBlank()) {
            throw new IllegalArgumentException("expectedToken must not be blank");
        }
        this.expectedToken = expectedToken;
    }

    @Override
    public <ReqT, RespT> ServerCall.Listener<ReqT> interceptCall(
            ServerCall<ReqT, RespT> call,
            Metadata headers,
            ServerCallHandler<ReqT, RespT> next) {

        String methodName = call.getMethodDescriptor().getFullMethodName();

        // The Authenticate RPC is permitted without header auth (it verifies token in request payload)
        if (methodName.endsWith("/Authenticate")) {
            return next.startCall(call, headers);
        }

        String providedToken = headers.get(AUTH_HEADER);
        boolean matches = providedToken != null &&
                java.security.MessageDigest.isEqual(
                        providedToken.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                        expectedToken.getBytes(java.nio.charset.StandardCharsets.UTF_8)
                );

        if (!matches) {
            log.warn("Rejected unauthorized local IPC call to {} from local client", methodName);
            call.close(Status.UNAUTHENTICATED.withDescription("Invalid or missing local IPC auth token"), new Metadata());
            return new ServerCall.Listener<>() {};
        }

        return next.startCall(call, headers);
    }
}
